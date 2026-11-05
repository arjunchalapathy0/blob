#!/usr/bin/env bash
# Archive, sign with Developer ID, notarize and staple.
# Usage: TEAM_ID=XXXXXXXXXX NOTARY_PROFILE=blob ./scripts/release.sh
# (create the profile once: xcrun notarytool store-credentials blob --apple-id you@example.com --team-id XXXXXXXXXX)
set -euo pipefail
cd "$(dirname "$0")/.."
: "${TEAM_ID:?set TEAM_ID}"; : "${NOTARY_PROFILE:?set NOTARY_PROFILE}"
xcodegen generate
rm -rf dist && mkdir -p dist
xcodebuild -project Blob.xcodeproj -scheme Blob -configuration Release \
  -archivePath dist/Blob.xcarchive DEVELOPMENT_TEAM="$TEAM_ID" archive
cat > dist/export.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>developer-id</string>
<key>teamID</key><string>${TEAM_ID}</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath dist/Blob.xcarchive -exportPath dist -exportOptionsPlist dist/export.plist
ditto -c -k --keepParent dist/Blob.app dist/Blob.zip
xcrun notarytool submit dist/Blob.zip --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple dist/Blob.app
ditto -c -k --keepParent dist/Blob.app dist/Blob.zip
echo "dist/Blob.zip is ready"
