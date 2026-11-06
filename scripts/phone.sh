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

if ! xcodebuild -project Blob.xcodeproj -scheme BlobPhone -configuration Debug \
     -destination "generic/platform=iOS" -derivedDataPath "$OUT/dd" \
     -allowProvisioningUpdates build > "$OUT/build.log" 2>&1; then
  grep -E "error:" "$OUT/build.log" | sort -u | head -n 15 || tail -n 25 "$OUT/build.log"
  exit 1
fi

APP="$OUT/dd/Build/Products/Debug-iphoneos/Blob.app"

# Pick a paired iPhone that this build's provisioning profile covers. Each Apple account's profile
# lists only its own registered devices, so this never tries to install your build on a friend's
# phone (or theirs on yours). Set BLOB_DEVICE to a name or UDID to choose one yourself.
security cms -D -i "$APP/embedded.mobileprovision" > "$OUT/profile.plist" 2>/dev/null || : > "$OUT/profile.plist"
xcrun devicectl list devices --json-output "$OUT/devices.json" >/dev/null 2>&1 || true
DEVICE="$(/usr/bin/python3 - "$OUT/devices.json" "$OUT/profile.plist" "${BLOB_DEVICE:-}" <<'PY'
import json, plistlib, sys
devices_path, profile_path, wanted = sys.argv[1], sys.argv[2], sys.argv[3].strip().lower()
try:
    devices = json.load(open(devices_path))["result"]["devices"]
except Exception:
    devices = []
try:
    allowed = set(plistlib.load(open(profile_path, "rb")).get("ProvisionedDevices", []))
except Exception:
    allowed = None  # no readable profile: install on any paired iPhone

def name(d): return d.get("deviceProperties", {}).get("name", "?")
def udid(d): return d.get("hardwareProperties", {}).get("udid", "")
def connected(d): return d.get("connectionProperties", {}).get("tunnelState") == "connected"

phones = [d for d in devices
          if d.get("hardwareProperties", {}).get("platform") == "iOS"
          and d.get("connectionProperties", {}).get("pairingState") == "paired"]
if wanted:
    phones = [d for d in phones if wanted in (name(d).lower(), udid(d).lower(), d.get("identifier", "").lower())]
covered = [d for d in phones if allowed is None or udid(d) in allowed]
reachable = [d for d in covered
             if d.get("connectionProperties", {}).get("tunnelState") != "unavailable"]
reachable.sort(key=lambda d: not connected(d))

if reachable:
    print(reachable[0]["identifier"])
elif covered:
    names = " or ".join(name(d) for d in covered)
    print(f"error: Can't reach {names}. Unlock it and plug it in, or put it on the same Wi-Fi.",
          file=sys.stderr)
else:
    others = ", ".join(name(d) for d in phones) or "none"
    print(f"error: None of the paired iPhones ({others}) can run this Apple account's build. "
          "Run Blob once on the right iPhone from Xcode so it gets registered.", file=sys.stderr)
PY
)"
[ -n "$DEVICE" ] || exit 1

xcrun devicectl device install app --device "$DEVICE" "$APP" > "$OUT/install.log" 2>&1 \
  || { grep -iE "error|unlock|trust" "$OUT/install.log" | head -n 5; exit 1; }
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 || true
echo "Installed on your iPhone."
