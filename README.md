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
| **Ask** | Ask Claude about what's on your screen. Blob captures the display (without itself) only when you hit Enter. Needs an Anthropic API key. |
| **Mirror** | Camera preview before calls, plus camera and microphone pickers (the mic picker sets the Mac's default input). The camera runs only while the tab is open. |
| **Voice agent** | Hold **right ⌥**, say what you want, let go. Whisper (WhisperKit, on-device) transcribes it, and Claude Code (your subscription) does it: runs commands, controls apps with AppleScript, opens things, looks at your screen. It asks before deleting, sending or buying. Typing in the Ask tab works the same way. |
| **Privacy lock** | Optional Touch ID (or password) lock on Clipboard, Shelf and Ask. |

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

## iPhone: Blob Island

The same project also builds a small iPhone app (iOS 17+). iOS doesn't let apps replace the Dynamic Island, so it uses Live Activities:

- **Timers**: count down in the Dynamic Island and on the Lock Screen, with a notification at the end.
- **Today**: tap **Island** on an event to count down to it.
- **Ask**: choose or paste a screenshot or photo and ask Claude about it (same API key setup).
- **Claude**: live Claude Code status from your Mac. Turn on Settings → Claude Code → **Show on iPhone** in the Mac app; both devices need to be on the same Wi-Fi. Status updates while the iPhone app is open.

**Without Xcode (SideStore):** every push to `main` builds `Blob.ipa` on GitHub Actions and attaches it to the **phone-latest** release. Set up [SideStore](https://sidestore.io) once (this step needs a computer). After that, open the release page on your iPhone, download `Blob.ipa`, and share it to SideStore. SideStore signs it with your Apple ID and refreshes it every 7 days from the phone.

**Building with a different Apple account** (e.g. a friend's phone): app IDs must be unique per account, so first run `./scripts/set-prefix.sh com.theirname`, reopen the project, and set their Team.

**Quick update:** Blob Settings → Updates → **Update iPhone** (after updating the Mac app), or `git pull && ./scripts/phone.sh`. It builds and installs over the cable or Wi-Fi, and also renews the 7-day limit.

To install with Xcode: open `Blob.xcodeproj`, choose the **BlobPhone** scheme and your iPhone as the destination, set your Team on both the **BlobPhone** and **BlobIsland** targets, and press Run. On the iPhone, trust your developer profile under Settings → General → VPN & Device Management. A free Apple account works; apps installed that way expire after 7 days, so run again from Xcode to renew.

## Build

```bash
./scripts/bootstrap.sh       # installs xcodegen + cmake, vendors the Now Playing adapter, generates the project
open Blob.xcodeproj          # choose your team under Signing & Capabilities, then Run
```

After changing `project.yml`, run `xcodegen generate` again. The `.xcodeproj` is generated and not committed.

### Updating

Blob can update itself. Settings → Updates → **Update**, or the ⬇ button in the notch header when a new version is waiting. It runs `scripts/update.sh`, which:
1. runs `git pull` in the source folder (the clone Blob was built from; you can change it in Settings),
2. rebuilds a Release copy with Xcode, signed with the same team as the running app,
3. quits Blob, replaces `/Applications/Blob.app` and relaunches it.

Blob checks for new commits at launch and every 6 hours. Because each build is signed with your own certificate, macOS keeps your permissions. You can also run it by hand: `./scripts/update.sh build`.

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
| Screen Recording | Ask (one screenshot per question) | Ask tab |
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
