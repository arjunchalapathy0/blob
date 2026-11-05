# Blob

A soft, monochrome notch for macOS. Blob replaces the dead space around the MacBook notch with a black shape that springs open on hover. A small grey character inside shows how things are going through motion alone.

macOS 14+ · Apple silicon and Intel · Swift / SwiftUI · no dependencies

## What it does

| | |
|---|---|
| **Now Playing** | Artwork, scrubber and controls. Live wings (art + equalizer) while music plays. |
| **System HUD** | Volume and brightness keys show in the notch instead of the macOS overlay. |
| **Shelf** | Drag files onto the notch to park them. Drag them out, AirDrop, reveal. |
| **Clipboard** | Recent copies; click to copy again, pin favorites. Password-manager items are skipped. |
| **Calendar** | Today at a glance, a countdown before meetings, and a one-click Join for Zoom/Meet/Teams links. |
| **Timers** | Quick presets, several at once, and a stopwatch. The countdown lives in the wings. |
| **Claude Code** | Shows when Claude is working, done, or waiting on you, per session. |
| **Tools** | Keep awake, color picker, screenshot to clipboard, dark mode, sleep display. |
| **Stats** | CPU, memory, network and battery with sparklines. Charger notices. |
| **Mirror** | Camera preview before calls; runs only while the tab is open. |

Every module can be switched off in Settings.

### The character

Blob is a grey rounded rectangle with two eyes, and only its motion changes:

- **idle**: slow breathing, blinks, glances around
- **curious** (you hover): leans in and its eyes follow the cursor
- **happy** (music playing): hops on a beat
- **busy** (Claude is working): wiggles while its eyes read left to right
- **alarmed** (timer done, Claude needs you): jumps and shakes
- **sleepy** (left alone for 10 minutes): squashes down, eyes shut, little z's

Moods blend into each other on a damped spring, so changes overshoot slightly and settle.

## Build

```bash
./scripts/bootstrap.sh       # installs xcodegen + cmake, vendors the Now Playing adapter, generates the project
open Blob.xcodeproj          # choose your team under Signing & Capabilities, then Run
```

After changing `project.yml`, run `xcodegen generate` again. The `.xcodeproj` is generated and not committed.

### Release (Developer ID + notarization)

```bash
xcrun notarytool store-credentials blob --apple-id you@example.com --team-id TEAMID
TEAM_ID=TEAMID NOTARY_PROFILE=blob ./scripts/release.sh   # produces dist/Blob.zip
```

Blob ships outside the App Store on purpose. The App Store sandbox would block the Now Playing adapter, the media-key tap and the Claude Code hook.

## Permissions

| Permission | Why | When it's asked |
|---|---|---|
| Accessibility | Catch volume/brightness keys to replace the system HUD | Settings → System HUD |
| Calendar | Upcoming events | Calendar tab |
| Camera | Mirror | Mirror tab |
| Automation (System Events, Music, Spotify) | Dark-mode toggle; AppleScript fallback for Now Playing | First use |

## How Now Playing works

macOS 15.4 stopped third-party apps from reading Now Playing through MediaRemote. Blob picks a source at launch:

1. **macOS 15.4+**: [`mediaremote-adapter`](https://github.com/ungive/mediaremote-adapter). The system `/usr/bin/perl` is still allowed to use MediaRemote, so Blob runs the adapter's script through it and reads a stream of JSON. `scripts/fetch-mediaremote-adapter.sh` builds it into `Vendor/`, and a build phase embeds and signs it.
2. **macOS 14 – 15.3**: MediaRemote directly.
3. **Fallback**: AppleScript for Music and Spotify, used if the adapter isn't bundled.

Settings → Now Playing shows which source is active.

## Claude Code integration

Settings → Claude Code → **Install** adds hooks to `~/.claude/settings.json` (it first saves a backup as `settings.json.blob-backup`):

```json
"hooks": { "PreToolUse": [{ "matcher": "*", "hooks": [{ "type": "command", "command": "\"/Applications/Blob.app/Contents/MacOS/Blob\" --claude-hook", "timeout": 5 }] }], ... }
```

Each hook runs the Blob binary in a headless mode that writes one small JSON file per session to `~/.blob/claude/` and exits. The running app watches that folder. Covered events: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Notification`, `Stop`, `SessionEnd`. If you move Blob.app, Settings offers to update the hook path.

## Layout

```
Blob/
  App/        entry point, app delegate, notch panel + window controller, settings window
  Core/       theme, springs, notch shape, geometry, prefs, view model, shared components
    Character/  moods and the procedural motion engine
  Views/      root, closed (wings + peek) and open (header + tabs) views
  Modules/    NowPlaying, SystemHUD, Shelf, Clipboard, Calendar, Timers, ClaudeCode, QuickTools, Stats, Camera
  Settings/   settings form
scripts/      bootstrap, adapter vendoring, release
```

## Tuning the feel

- Springs: `Blob/Core/Springs.swift`
- Notch sizes and corner radii: `NotchViewModel.openSize`, `bodySize`, `topRadius`, `bottomRadius`
- Wing widths per activity: `LiveActivity.wingWidth`
- Character motion: `Mood.pose(at:)` in `Blob/Core/Character/Mood.swift`
- Colors: `Blob/Core/Theme.swift` (black surface, white ink at a few opacities, one grey)
