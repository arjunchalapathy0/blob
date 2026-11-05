#!/usr/bin/env bash
# Used by Blob's Update button. Also works by hand.
#   update.sh check                      -> prints behind=<n> and summary=<latest commit>
#   update.sh build [team-id]            -> pulls, builds Release, prints app=<path>
#   update.sh install <new> <dest> <pid> -> waits for Blob to quit, replaces it, relaunches
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

case "${1:-}" in
  check)
    git fetch --quiet origin
    UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}')"
    echo "behind=$(git rev-list --count "HEAD..$UPSTREAM")"
    echo "summary=$(git log -1 --format=%s "$UPSTREAM")"
    ;;

  build)
    TEAM="${2:-}"
    git pull --ff-only --quiet
    command -v xcodegen >/dev/null || brew install xcodegen >/dev/null
    if [ ! -d Vendor/MediaRemoteAdapter/MediaRemoteAdapter.framework ]; then
      command -v cmake >/dev/null || brew install cmake >/dev/null
      ./scripts/fetch-mediaremote-adapter.sh >/dev/null 2>&1
    fi
    xcodegen generate --quiet
    OUT="$ROOT/build/update"
    rm -rf "$OUT" && mkdir -p "$OUT"
    if [ -n "$TEAM" ]; then
      SIGN=(DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates)
    else
      SIGN=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=)
    fi
    if ! xcodebuild -project Blob.xcodeproj -target Blob -configuration Release \
         SYMROOT="$OUT" "${SIGN[@]}" build >"$OUT/build.log" 2>&1; then
      grep -E "error:" "$OUT/build.log" | head -n 15 || tail -n 25 "$OUT/build.log"
      exit 1
    fi
    echo "app=$OUT/Release/Blob.app"
    ;;

  install)
    NEW="$2"; DEST="$3"; PID="$4"
    while kill -0 "$PID" 2>/dev/null; do sleep 0.2; done
    rm -rf "$DEST"
    ditto "$NEW" "$DEST"
    open "$DEST"
    ;;

  *)
    echo "usage: update.sh check | build [team-id] | install <new> <dest> <pid>" >&2
    exit 2
    ;;
esac
