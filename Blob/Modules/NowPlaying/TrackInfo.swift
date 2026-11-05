import Foundation

struct TrackInfo: Equatable {
    var title = ""
    var artist = ""
    var album = ""
    var duration: Double = 0
    var elapsed: Double = 0
    /// When `elapsed` was measured.
    var timestamp = Date()
    var rate: Double = 1
    var isPlaying = false
    var bundleID: String?
    var artworkData: Data?

    /// Playback position extrapolated to `date`.
    func elapsed(at date: Date) -> Double {
        guard isPlaying else { return elapsed }
        let value = elapsed + date.timeIntervalSince(timestamp) * (rate == 0 ? 1 : rate)
        return duration > 0 ? min(max(0, value), duration) : max(0, value)
    }
}

enum MediaCommand: Int {
    case play = 0, pause = 1, togglePlayPause = 2, nextTrack = 4, previousTrack = 5
}

/// A source of Now Playing information. Callbacks may arrive on any thread.
protocol NowPlayingBackend: AnyObject {
    var name: String { get }
    var onUpdate: ((TrackInfo?) -> Void)? { get set }
    func start()
    func stop()
    func send(_ command: MediaCommand)
    func seek(to seconds: Double)
}
