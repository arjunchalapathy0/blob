#!/usr/bin/env bash
# One-time setup so downloaded copies of Blob keep their macOS permissions across updates.
#
# Makes a self-signed code-signing certificate ("Blob Self-Signed") and saves it as the
# MAC_SIGN_P12 / MAC_SIGN_PASSWORD secrets of the GitHub repo, which the Mac release
# workflow uses. It is NOT an Apple Developer ID: macOS still asks people to click
# "Open Anyway" the first time. It only makes every release look like the same app.
#
# Needs: openssl, and the GitHub CLI signed in (brew install gh && gh auth login).
# Keep the files it writes in ~/.blob-signing safe; you need the same certificate forever.
set -euo pipefail
REPO="${REPO:-arjunchalapathy0/blob}"
DIR="$HOME/.blob-signing"
mkdir -p "$DIR" && chmod 700 "$DIR"
cd "$DIR"

if [ ! -f blob.p12 ]; then
  cat > cert.cnf <<'CNF'
[req]
distinguished_name = dn
prompt = no
x509_extensions = ext
[dn]
CN = Blob Self-Signed
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF
  openssl req -x509 -newkey rsa:2048 -nodes -days 7300 -keyout key.pem -out cert.pem -config cert.cnf
  PASSWORD="$(openssl rand -hex 16)"
  echo "$PASSWORD" > password.txt
  # -legacy keeps the .p12 readable by macOS's `security import`.
  openssl pkcs12 -export -legacy -inkey key.pem -in cert.pem -name "Blob Self-Signed" \
    -out blob.p12 -passout pass:"$PASSWORD" 2>/dev/null \
  || openssl pkcs12 -export -inkey key.pem -in cert.pem -name "Blob Self-Signed" -out blob.p12 -passout pass:"$PASSWORD"
  rm key.pem
  chmod 600 blob.p12 password.txt
fi

base64 < blob.p12 | gh secret set MAC_SIGN_P12 --repo "$REPO"
gh secret set MAC_SIGN_PASSWORD --repo "$REPO" < password.txt
echo "Saved. The next Mac release will be signed as \"Blob Self-Signed\"."
echo "Back up $DIR — losing it means people re-grant permissions once."
