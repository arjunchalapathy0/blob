import AppKit

@MainActor
final class NowPlayingService: ObservableObject {
    @Published private(set) var track: TrackInfo?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var appIcon: NSImage?
    @Published private(set) var backendName = ""

    private var backend: NowPlayingBackend?

    var isPlaying: Bool { track?.isPlaying ?? false }

    func start() {
        guard backend == nil else { return }
        let b = Self.makeBackend()
        b.onUpdate = { [weak self] info in
            Task { @MainActor in self?.apply(info) }
        }
        backend = b
        backendName = b.name
        b.start()
    }

    func stop() { backend?.stop() }

    func togglePlayPause() {
        backend?.send(.togglePlayPause)
        if var t = track {
            t.elapsed = t.elapsed(at: Date())
            t.timestamp = Date()
            t.isPlaying.toggle()
            track = t
        }
    }

    func next() { backend?.send(.nextTrack) }
    func previous() { backend?.send(.previousTrack) }

    func seek(to seconds: Double) {
        backend?.seek(to: seconds)
        if var t = track {
            t.elapsed = seconds
            t.timestamp = Date()
            track = t
        }
    }

    func openPlayer() {
        guard let id = track?.bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return }
        NSWorkspace.shared.open(url)
    }

    private func apply(_ info: TrackInfo?) {
        guard let info, !info.title.isEmpty else {
            if track != nil { track = nil; artwork = nil; appIcon = nil }
            return
        }
        if info.artworkData != track?.artworkData {
            artwork = info.artworkData.flatMap(NSImage.init(data:))
        }
        if info.bundleID != track?.bundleID {
            appIcon = info.bundleID
                .flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
                .map { NSWorkspace.shared.icon(forFile: $0.path) }
        }
        if info != track { track = info }
    }

    /// macOS 15.4 and later reject MediaRemote calls from third-party apps, so use the
    /// perl-hosted adapter there. Earlier versions can call MediaRemote directly.
    /// AppleScript (Music and Spotify) is the last resort.
    private static func makeBackend() -> NowPlayingBackend {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let restricted = v.majorVersion > 15 || (v.majorVersion == 15 && v.minorVersion >= 4)
        if restricted {
            if let adapter = AdapterBackend() { return adapter }
            return AppleScriptBackend()
        }
        return MediaRemoteBackend() ?? AppleScriptBackend()
    }
}
