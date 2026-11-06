#!/usr/bin/env bash
# One-time setup: installs tools, vendors the Now Playing adapter, generates Blob.xcodeproj.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || brew install xcodegen
command -v cmake >/dev/null || brew install cmake
[ -d Vendor/MediaRemoteAdapter/MediaRemoteAdapter.framework ] || ./scripts/fetch-mediaremote-adapter.sh
source ./scripts/team.sh
[ -f Config/Local.xcconfig ] || save_team "$PWD"
xcodegen generate
echo "Open Blob.xcodeproj, pick your team under Signing, then Run."
