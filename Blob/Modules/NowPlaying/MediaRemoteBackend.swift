import AppKit

/// Direct MediaRemote access. Works on macOS 14 through 15.3.
final class MediaRemoteBackend: NowPlayingBackend {
    let name = "MediaRemote"
    var onUpdate: ((TrackInfo?) -> Void)?

    private typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias GetIsPlayingFn = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private typealias GetPIDFn = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
    private typealias RegisterFn = @convention(c) (DispatchQueue) -> Void
    private typealias SendFn = @convention(c) (Int, AnyObject?) -> Bool
    private typealias SetElapsedFn = @convention(c) (Double) -> Void

    private let getInfo: GetInfoFn
    private let getIsPlaying: GetIsPlayingFn
    private let getPID: GetPIDFn?
    private let register: RegisterFn
    private let sendCommand: SendFn
    private let setElapsed: SetElapsedFn
    private let queue = DispatchQueue(label: "blob.nowplaying.mediaremote")
    private var observers: [NSObjectProtocol] = []
    private var timer: DispatchSourceTimer?

    init?() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let h = dlopen(path, RTLD_NOW),
              let a = dlsym(h, "MRMediaRemoteGetNowPlayingInfo"),
              let b = dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying"),
              let c = dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications"),
              let d = dlsym(h, "MRMediaRemoteSendCommand"),
              let e = dlsym(h, "MRMediaRemoteSetElapsedTime") else { return nil }
        getInfo = unsafeBitCast(a, to: GetInfoFn.self)
        getIsPlaying = unsafeBitCast(b, to: GetIsPlayingFn.self)
        register = unsafeBitCast(c, to: RegisterFn.self)
        sendCommand = unsafeBitCast(d, to: SendFn.self)
        setElapsed = unsafeBitCast(e, to: SetElapsedFn.self)
        getPID = dlsym(h, "MRMediaRemoteGetNowPlayingApplicationPID").map { unsafeBitCast($0, to: GetPIDFn.self) }
    }

    func start() {
        register(queue)
        let names = [
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
        ]
        observers = names.map {
            NotificationCenter.default.addObserver(forName: Notification.Name($0), object: nil, queue: nil) { [weak self] _ in
                self?.refresh()
            }
        }
        // Safety net: some players don't post every change.
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 2, repeating: 3)
        t.setEventHandler { [weak self] in self?.refresh() }
        t.resume()
        timer = t
        refresh()
    }

    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        timer?.cancel()
    }

    func send(_ command: MediaCommand) { _ = sendCommand(command.rawValue, nil) }

    func seek(to seconds: Double) { setElapsed(seconds) }

    private func refresh() {
        getInfo(queue) { [weak self] info in
            guard let self else { return }
            self.getIsPlaying(self.queue) { playing in
                guard var track = Self.parse(info) else { self.onUpdate?(nil); return }
                track.isPlaying = playing
                if let getPID = self.getPID {
                    getPID(self.queue) { pid in
                        track.bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
                        self.onUpdate?(track)
                    }
                } else {
                    self.onUpdate?(track)
                }
            }
        }
    }

    private static func parse(_ info: [String: Any]) -> TrackInfo? {
        let prefix = "kMRMediaRemoteNowPlayingInfo"
        guard let title = info[prefix + "Title"] as? String, !title.isEmpty else { return nil }
        var t = TrackInfo()
        t.title = title
        t.artist = info[prefix + "Artist"] as? String ?? ""
        t.album = info[prefix + "Album"] as? String ?? ""
        t.duration = (info[prefix + "Duration"] as? NSNumber)?.doubleValue ?? 0
        t.elapsed = (info[prefix + "ElapsedTime"] as? NSNumber)?.doubleValue ?? 0
        t.rate = (info[prefix + "PlaybackRate"] as? NSNumber)?.doubleValue ?? 1
        t.timestamp = info[prefix + "Timestamp"] as? Date ?? Date()
        t.artworkData = info[prefix + "ArtworkData"] as? Data
        return t
    }
}
