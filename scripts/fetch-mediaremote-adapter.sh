#!/usr/bin/env bash
# Builds ungive/mediaremote-adapter and vendors it into Vendor/MediaRemoteAdapter.
# Needed for Now Playing on macOS 15.4 and later. Requires cmake (brew install cmake).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Vendor/src/mediaremote-adapter"
OUT="$ROOT/Vendor/MediaRemoteAdapter"
REF="${1:-master}"

if [ ! -d "$SRC/.git" ]; then
  git clone https://github.com/ungive/mediaremote-adapter.git "$SRC"
fi
git -C "$SRC" fetch --depth 1 origin "$REF" && git -C "$SRC" checkout -q FETCH_HEAD

cmake -S "$SRC" -B "$SRC/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
cmake --build "$SRC/build" --config Release

FW="$(find "$SRC/build" -maxdepth 3 -name 'MediaRemoteAdapter.framework' -type d | head -n1)"
PL="$(find "$SRC" -maxdepth 3 -name 'mediaremote-adapter.pl' -type f | head -n1)"
[ -n "$FW" ] && [ -n "$PL" ] || { echo "Could not find build outputs" >&2; exit 1; }

rm -rf "$OUT" && mkdir -p "$OUT"
cp -R "$FW" "$OUT/"
cp "$PL" "$OUT/"
echo "Vendored into $OUT"
