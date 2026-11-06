#!/usr/bin/env bash
# Builds Blob for iPhone and installs it on your iPhone: over the cable, or over Wi-Fi once the
# phone has been connected to Xcode before. Also renews the free-account 7-day limit.
#   ./scripts/phone.sh            (run `git pull` first to get the latest code)
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

command -v xcodegen >/dev/null || brew install xcodegen >/dev/null
source "$ROOT/scripts/team.sh"
[ -f Config/Local.xcconfig ] || save_team "$ROOT"
xcodegen generate --quiet

OUT="$ROOT/build/phone"
mkdir -p "$OUT"

# Find a paired iPhone.
xcrun devicectl list devices --json-output "$OUT/devices.json" >/dev/null 2>&1 || true
DEVICE="$(/usr/bin/python3 - "$OUT/devices.json" <<'PY'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    devices = []
phones = [d for d in devices
          if d.get("hardwareProperties", {}).get("platform") == "iOS"
          and d.get("connectionProperties", {}).get("pairingState") == "paired"]
phones.sort(key=lambda d: d.get("connectionProperties", {}).get("tunnelState") != "connected")
print(phones[0]["identifier"] if phones else "")
PY
)"
if [ -z "$DEVICE" ]; then
  echo "error: No paired iPhone found. Plug it in and unlock it, or make sure it's on the same Wi-Fi."
  exit 1
fi

if ! xcodebuild -project Blob.xcodeproj -scheme BlobPhone -configuration Debug \
     -destination "generic/platform=iOS" -derivedDataPath "$OUT/dd" \
     -allowProvisioningUpdates build > "$OUT/build.log" 2>&1; then
  grep -E "error:" "$OUT/build.log" | sort -u | head -n 15 || tail -n 25 "$OUT/build.log"
  exit 1
fi

APP="$OUT/dd/Build/Products/Debug-iphoneos/Blob.app"
xcrun devicectl device install app --device "$DEVICE" "$APP" > "$OUT/install.log" 2>&1 \
  || { grep -iE "error|unlock|trust" "$OUT/install.log" | head -n 5; exit 1; }
xcrun devicectl device process launch --device "$DEVICE" app.blob.BlobPhone >/dev/null 2>&1 || true
echo "Installed on your iPhone."
