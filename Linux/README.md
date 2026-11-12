# Blob for Linux

A port of Blob to Linux desktops, written in C# with Avalonia (.NET 8). Most screens don't have a
notch, so Blob lives in a small black pill hanging from the top-centre of the screen, like on Windows.

## Install

```sh
curl -fsSL https://blobnotch.app/linux/install.sh | sh
```

It installs for the current user only (no sudo): the app goes in `~/.local/share/blob/app`, a `blob`
command in `~/.local/bin`, and Blob is added to the apps menu and to sign-in. Run `blob --uninstall`
to take it back out.

## What it does

- **Blob**, with the same moods and springs as the Mac app.
- **Hover to peek, keep hovering or click to open.** Esc closes; the pin keeps it open. Only the notch
  itself takes the mouse, so clicks beside it go through to whatever is underneath.
- **A welcome on first launch** that checks for Claude Code, a recorder and the talk key.
- **Ask**: type, click a suggestion, or talk. Whisper (base.en, about 150 MB, downloaded once) turns
  speech into text on the computer, and Claude Code carries it out on your own Claude subscription.
- **Talking:** on X11, hold **Right Alt** anywhere (or Right Ctrl, if Right Alt is AltGr on your
  layout). On Wayland, apps can't see keys pressed in other apps, so hold the microphone button in the
  notch, or bind a keyboard shortcut to `blob --toggle-talk`.
- **Now Playing** from any player that speaks MPRIS (Spotify, browsers, VLC…), with controls.
- **Timers**, several at once, counting down in the notch.
- **Clipboard history** in memory. Copies marked by password managers are skipped.
- **Claude Code sessions**: working, done or waiting on you, through the same `--claude-hook` hooks
  as the Mac and Windows apps.
- A tray icon (where the desktop has one), launch at sign-in, and an Update button that downloads new
  builds from blobnotch.app.

## On a Chromebook

Blob runs in ChromeOS's Linux development environment (turn it on in Settings → About ChromeOS →
Developers, then run the install command in the Terminal app). ChromeOS places Linux windows itself and
won't keep one on top or see-through, so on a Chromebook Blob is a small ordinary window instead of a
notch: always open, moved and closed like any other app, and closing it quits Blob.

- Talk by holding the microphone button. ChromeOS doesn't let Linux apps see other apps' keys or bind
  keyboard shortcuts to Linux commands, and the microphone has to be allowed in Settings → About
  ChromeOS → Developers → Linux development environment.
- Claude Code works inside Linux only. Blob tells it it's on a Chromebook, so it says when a request
  needs Chrome, ChromeOS settings or Android apps, which it can't reach.
- Now Playing only sees music in Linux apps, not in Chrome tabs.
- Blob can't start at sign-in there (ChromeOS starts Linux only when it's needed).
- School and work Chromebooks often have Linux turned off by the administrator.

Blob detects ChromeOS by itself (`/dev/.cros_milestone`). `BLOB_CHROMEOS=1` or `0` overrides it.

Not on Linux yet: the volume/brightness HUD, Shelf, Calendar, Stats, Mirror, the privacy lock and
iPhone pairing.

## Commands

```
blob                   start Blob, or open it if it's already running
blob --toggle-talk     start listening; run it again to stop (bind this to a shortcut)
blob --ask "…"         ask Blob to do something
blob --settings        open Settings
blob --quit            quit Blob
blob --install         add Blob to the apps menu and start it at sign-in
blob --uninstall       undo --install, and disconnect Claude Code
blob --self-test       check the display, Whisper, recorder, Claude Code and media controls
```

## Needs

- x64 or ARM64, with an X11 desktop or Wayland with XWayland (GNOME, KDE, Xfce, Cinnamon, i3…).
- For talking: `parecord` (pulseaudio-utils), `arecord` (alsa-utils) or `pw-record`.
- For Now Playing: `busctl` (part of systemd).
- For Ask: [Claude Code](https://claude.com/claude-code), signed in.

Without a compositor, a see-through window would be drawn black, so Blob cuts its window to the
notch's shape instead.

## Build

```sh
dotnet run --project Linux/Blob
```

Releases are built by `.github/workflows/linux-release.yml` (Actions → Linux release → Run workflow),
which publishes `blob-site/public/linux/` and the install script.

## How it was tested

On a virtual X desktop (Xvfb, Openbox, with and without the picom compositor): the welcome, hover and
click-through, Ask with a stand-in for Claude Code, typing, timers, clipboard history from another
app, Now Playing from a pretend MPRIS player, the Claude Code hook, holding Right Alt (and that
Right Alt + another key doesn't trigger it), commands to the running app, Settings, the installer,
and the packaged build's `--self-test`. The Chromebook mode was run the same way with `BLOB_CHROMEOS=1`
(the window, Ask, staying open, and closing it to quit). Not tested yet: a real Chromebook, a real
GNOME or KDE session, real Wayland, a real microphone, and the arm64 build.
