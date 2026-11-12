#!/bin/sh
# Installs Blob for Linux for the current user (no sudo):
#   curl -fsSL https://blobnotch.app/linux/install.sh | sh
#
# Puts the app in ~/.local/share/blob/app, a `blob` command in ~/.local/bin,
# adds Blob to the apps menu and to sign-in, then starts it.
# To remove it: blob --uninstall && rm -rf ~/.local/share/blob ~/.local/bin/blob
set -eu

BASE="${BLOB_BASE:-https://blobnotch.app}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/blob"
APP="$DATA/app"
BIN="$HOME/.local/bin"

say() { printf '%s\n' "$*"; }
fail() { printf 'Blob: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Linux" ] || fail "this installer is for Linux. On a Mac or Windows PC, download Blob from $BASE."
CHROMEOS=""
if [ -e /dev/.cros_milestone ] || [ -d /opt/google/cros-containers ]; then CHROMEOS=1; fi
case "$(uname -m)" in
  x86_64 | amd64) ARCH=x64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  *) fail "there's no build for $(uname -m) yet." ;;
esac

if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -qO "$2" "$1"; }
else
  fail "needs curl or wget."
fi
command -v tar >/dev/null 2>&1 || fail "needs tar."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "Downloading Blob for Linux ($ARCH)…"
fetch "$BASE/linux/Blob-Linux-$ARCH.tar.gz" "$TMP/blob.tar.gz" || fail "couldn't download it. Check your connection and try again."
tar -xzf "$TMP/blob.tar.gz" -C "$TMP" || fail "the download was damaged. Try again."
[ -x "$TMP/Blob/Blob" ] || fail "the download didn't contain Blob."

# Quit a running copy before replacing it.
if [ -x "$APP/Blob" ]; then "$APP/Blob" --quit >/dev/null 2>&1 || true; sleep 1; fi
mkdir -p "$DATA" "$BIN"
rm -rf "$APP.new"
mv "$TMP/Blob" "$APP.new"
rm -rf "$APP"
mv "$APP.new" "$APP"
ln -sf "$APP/Blob" "$BIN/blob"

"$APP/Blob" --install >/dev/null
say "Installed Blob $("$APP/Blob" --version | cut -d' ' -f2) in $APP."

if [ -n "$CHROMEOS" ]; then
  say "On a Chromebook, Blob opens as a small window. Find it in the launcher under Linux apps."
  say "To talk to it, allow the microphone: Settings → About ChromeOS → Developers → Linux development environment."
else
  case ":$PATH:" in
    *":$BIN:"*) ;;
    *) say "Note: $BIN isn't on your PATH, so open Blob from the apps menu or run $BIN/blob." ;;
  esac
fi

# Things Blob uses if they're there.
if ! command -v parecord >/dev/null 2>&1 && ! command -v arecord >/dev/null 2>&1 && ! command -v pw-record >/dev/null 2>&1; then
  say "To talk to Blob, install a recorder: pulseaudio-utils (or alsa-utils)."
fi
if ! command -v claude >/dev/null 2>&1; then
  say "Blob does things through Claude Code. Install it from https://claude.com/claude-code and sign in."
fi

if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  nohup "$APP/Blob" >/dev/null 2>&1 &
  say "Blob is starting. Look at the top of your screen."
else
  say "Blob will start the next time you sign in, or open it from the apps menu."
fi
