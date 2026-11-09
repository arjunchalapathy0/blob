# Blob for Windows

A port of Blob to Windows 10 and 11, written in C# / WPF (.NET 8). Most PCs don't have a notch,
so Blob lives in a small black pill hanging from the top-centre of the screen.

## What it does

- **Blob**, the same character, moods and springs as the Mac app (ported from `Mood.swift`).
- **Hover to peek, keep hovering or click to open.** Esc closes. The pin keeps it open.
- **Hold Right Alt and talk.** Whisper (base.en, ~150 MB, downloaded once) turns it into text on the
  PC, and Claude Code carries it out using your own Claude subscription. Typing works too.
  If Right Alt is AltGr on your keyboard, switch to Right Ctrl in Settings.
- **Now Playing** from anything in Windows' media controls (Spotify, browsers…), with controls.
- **Timers**, several at once, counting down in the notch.
- **Clipboard history** in memory. Password-manager copies are skipped.
- **Claude Code sessions**: working, done or waiting on you, through the same `--claude-hook` hooks as the Mac.
- **Windows Hello lock** for Clipboard and Ask: face on PCs with an IR camera, or fingerprint/PIN.
- Launch at sign-in, tray icon, and an Update button that downloads new builds from blobnotch.app.

Not yet on Windows: volume/brightness HUD, Shelf, Calendar, Stats, Mirror, iPhone pairing.

## Needs

- Windows 10 (2004) or 11, x64 (ARM PCs run it through emulation).
- The free [.NET 8 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/8.0). Windows offers it on first launch.
- For Ask: [Claude Code](https://code.claude.com/docs), signed in, and Git for Windows (Claude Code needs it).

## Build

```
dotnet run --project Windows/Blob
```

Releases are built by `.github/workflows/windows-release.yml` (Actions → Windows release → Run workflow),
which publishes `blob-site/public/windows/Blob-Windows.zip` and `version.json`.

The project also compiles on macOS/Linux (`EnableWindowsTargeting`), which is handy for checking changes,
but it only runs on Windows.
