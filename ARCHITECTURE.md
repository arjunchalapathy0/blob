# Blob — Architecture

A notch replacement for macOS 14+ (Apple silicon and Intel). It is a SwiftUI app hosted in an AppKit panel, with modular features and one animation language: continuous corners, springs, and a grey character that shows mood through motion.

## Stack
- **Swift 5.10+, SwiftUI with AppKit glue.** A borderless, non-activating `NSPanel` at `.statusBar + 1` level, on all Spaces, and above full-screen apps when the user opts in.
- **XcodeGen (`project.yml`)**, so the `.xcodeproj` is generated rather than committed and merge conflicts stay low.
- **Not sandboxed.** Developer ID signing plus notarization, distributed outside the App Store. The sandbox would block the Now Playing adapter, the event tap and the Claude Code socket.
- Universal binary (arm64 + x86_64).

## Layout
```
Blob/
  App/            BlobApp.swift, AppDelegate, NotchPanel (NSPanel), ScreenObserver
  Core/
    Geometry/     NotchGeometry (reads safeAreaInsets / auxiliaryTopLeftArea), fallback pill for non-notch screens
    Motion/       Springs.swift (named presets: .snap, .soft, .wobble), BlobShape (animatable continuous-corner shape)
    State/        NotchState (closed / peek / open / alert), NotchViewModel, ModuleRegistry
    Character/    BlobCharacter view + Mood enum (idle, curious, happy, sleepy, busy, alarmed) driven by a tiny motion engine
  Modules/        Each one follows `NotchModule` (id, peek view, expanded view, priority, settings view)
    NowPlaying/   MediaRemoteAdapter wrapper + AppleScript fallback
    SystemHUD/    volume / brightness / keyboard backlight (CGEventTap + OSD suppression)
    Shelf/        drag-and-drop file shelf (security-scoped bookmarks)
    Clipboard/    NSPasteboard changeCount polling, history store
    Calendar/     EventKit: next event and countdown
    Timers/       timers and stopwatch
    ClaudeCode/   status-file watcher fed by `Blob --claude-hook` (working / waiting / done)
    QuickTools/   color picker, caffeinate, screenshot, etc.
    Stats/        CPU / RAM / net / battery (host_statistics, IOKit)
    Camera/       AVCaptureSession mirror
  Settings/       SwiftUI Settings scene; per-module enable and order
  Resources/      Assets, vendored MediaRemoteAdapter.framework + perl script
```

## Key decisions
1. **Now Playing.** On macOS 15.4+, private MediaRemote calls are rejected for third-party processes. Plan: vendor `mediaremote-adapter`, which runs through `/usr/bin/perl` and gets data because that binary is entitled, and stream its JSON lines. Use direct MediaRemote on 14.x through 15.3, and AppleScript for Music/Spotify as a last resort. Its per-app commands are incomplete, so transport controls only target the system's current player.
2. **System HUD replacement.** This needs Accessibility permission for a `CGEventTap` that catches media keys. The tap also has to suppress the system OSD. We can't hide Apple's OSD cleanly, so the tap swallows the key and sets the volume or brightness itself (CoreAudio, plus DisplayServices for brightness).
3. **Claude Code status.** Claude Code hooks run `Blob --claude-hook`, which writes one JSON status file per session to `~/.blob/claude/`. The app watches that folder, so Blob can show working, needs-input and done states per session.
4. **Animation.** A single `NotchState` machine drives one `BlobShape` with animatable width, height and corner radius, so every transition is the same spring and only the parameters change. Character moods are small procedural motions (squash/stretch, blink, look-at-cursor), not sprite sheets.

## Phases
1. Panel, notch geometry, hover/click open and close with spring, idle character. Settings shell.
2. Now Playing (adapter + fallback), plus character reacting to music.
3. System HUD (volume and brightness) with onboarding for Accessibility permission.
4. Shelf, Clipboard, Timers.
5. Calendar, Claude Code status, Stats.
6. Quick Tools, Camera, polish, signing/notarization, Sparkle updates.

## Decisions confirmed
- Now Playing: adapter + direct MediaRemote + AppleScript fallback.
- Distribution: Developer ID + notarization, not sandboxed.
- Look: monochrome (black surface, white ink, one grey for the character). Album art is the only color, and it can be made greyscale too.
- Claude Code: the hook runs the app binary with `--claude-hook`, which writes status files to `~/.blob/claude/`. The app watches the folder, so it needs no socket and no extra runtime.
- Sparkle auto-updates are not included yet. Add the package and an appcast when there's a release channel.

## Status
All six phases are implemented. The code was written in a Linux session, so it has **not been compiled or run yet**. The first build on a Mac may surface small compile fixes, and the springs and sizes will need tuning by feel.
