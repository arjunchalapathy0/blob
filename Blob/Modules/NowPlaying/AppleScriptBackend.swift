import AppKit

/// Last-resort Now Playing for Music and Spotify through AppleScript. Polls only apps
/// that are already running, so it never launches a player.
final class AppleScriptBackend: NowPlayingBackend {
    let name = "AppleScript (Music, Spotify)"
    var onUpdate: ((TrackInfo?) -> Void)?

    private struct Player { let bundleID: String; let name: String }
    private let players = [Player(bundleID: "com.apple.Music", name: "Music"),
                           Player(bundleID: "com.spotify.client", name: "Spotify")]
    private var timer: Timer?
    private var current: Player?
    private var lastKey = ""
    private var artwork: Data?

    func start() {
        let t = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        poll()
    }

    func stop() { timer?.invalidate() }

    func send(_ command: MediaCommand) {
        guard let p = current else { return }
        let verb: String
        switch command {
        case .play: verb = "play"
        case .pause: verb = "pause"
        case .togglePlayPause: verb = "playpause"
        case .nextTrack: verb = "next track"
        case .previousTrack: verb = "previous track"
        }
        _ = run("tell application \"\(p.name)\" to \(verb)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.poll() }
    }

    func seek(to seconds: Double) {
        guard let p = current else { return }
        _ = run("tell application \"\(p.name)\" to set player position to \(seconds)")
    }

    private func isRunning(_ p: Player) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: p.bundleID).isEmpty
    }

    private func poll() {
        var best: (Player, TrackInfo)?
        for p in players where isRunning(p) {
            guard let info = read(p) else { continue }
            if info.isPlaying { best = (p, info); break }
            if best == nil { best = (p, info) }
        }
        guard let best else {
            current = nil
            onUpdate?(nil)
            return
        }
        let (player, info) = best
        current = player
        var track = info
        let key = "\(player.bundleID)|\(info.title)|\(info.artist)"
        if key != lastKey {
            lastKey = key
            artwork = nil
            loadArtwork(player)
        }
        track.artworkData = artwork
        onUpdate?(track)
    }

    private func read(_ p: Player) -> TrackInfo? {
        let script = """
        tell application "\(p.name)"
            if player state is stopped then return {}
            set t to current track
            return {name of t, artist of t, album of t, duration of t, player position, (player state is playing)}
        end tell
        """
        guard let d = run(script), d.numberOfItems >= 6 else { return nil }
        var t = TrackInfo()
        t.title = d.atIndex(1)?.stringValue ?? ""
        t.artist = d.atIndex(2)?.stringValue ?? ""
        t.album = d.atIndex(3)?.stringValue ?? ""
        let duration = d.atIndex(4)?.doubleValue ?? 0
        t.duration = p.bundleID == "com.spotify.client" ? duration / 1000 : duration
        t.elapsed = d.atIndex(5)?.doubleValue ?? 0
        t.isPlaying = d.atIndex(6)?.booleanValue ?? false
        t.timestamp = Date()
        t.rate = 1
        t.bundleID = p.bundleID
        return t.title.isEmpty ? nil : t
    }

    private func loadArtwork(_ p: Player) {
        if p.bundleID == "com.apple.Music" {
            let d = run("tell application \"Music\" to tell artwork 1 of current track to return raw data")
                ?? run("tell application \"Music\" to tell artwork 1 of current track to return data")
            artwork = d?.data
        } else if let s = run("tell application \"Spotify\" to return artwork url of current track")?.stringValue,
                  let url = URL(string: s) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                DispatchQueue.main.async { self?.artwork = data }
            }.resume()
        }
    }

    private func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }
}
