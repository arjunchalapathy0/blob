#!/usr/bin/env bash
# Gives your copy of Blob its own app IDs (needed when building with a different Apple account).
#   ./scripts/set-prefix.sh com.yourname
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${1:-}"
if ! [[ "$PREFIX" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]]; then
  echo "usage: ./scripts/set-prefix.sh com.yourname   (letters, numbers, dots and dashes)"
  exit 1
fi
FILE="$ROOT/Config/Local.xcconfig"
mkdir -p "$ROOT/Config"
touch "$FILE"
grep -v '^BLOB_BUNDLE_PREFIX' "$FILE" > "$FILE.tmp" || true
echo "BLOB_BUNDLE_PREFIX = $PREFIX" >> "$FILE.tmp"
mv "$FILE.tmp" "$FILE"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
(cd "$ROOT" && xcodegen generate --quiet)
echo "App IDs now start with $PREFIX (e.g. $PREFIX.BlobPhone). Reopen Blob.xcodeproj."
