import AppKit
import Combine

struct BlobTimer: Identifiable, Equatable, Codable {
    var id = UUID()
    var label: String
    var duration: TimeInterval
    var endDate: Date
    var pausedRemaining: TimeInterval?

    var isPaused: Bool { pausedRemaining != nil }

    func remaining(at date: Date) -> TimeInterval {
        pausedRemaining ?? max(0, endDate.timeIntervalSince(date))
    }

    func progress(at date: Date) -> Double {
        duration > 0 ? 1 - remaining(at: date) / duration : 0
    }
}

@MainActor
final class TimerService: ObservableObject {
    @Published private(set) var timers: [BlobTimer] = []
    @Published private(set) var ringing: BlobTimer?
    @Published private(set) var stopwatchStart: Date?
    @Published private(set) var stopwatchAccumulated: TimeInterval = 0

    private let notices: NoticeCenter
    private var bag = Set<AnyCancellable>()
    private var ringTask: Task<Void, Never>?
    private let file: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Blob", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("timers.json")
    }()

    init(notices: NoticeCenter) {
        self.notices = notices
        load()
    }

    /// The running timer that finishes first.
    var primary: BlobTimer? {
        let now = Date()
        return timers.filter { !$0.isPaused }.min { $0.remaining(at: now) < $1.remaining(at: now) }
    }

    var isStopwatchRunning: Bool { stopwatchStart != nil }

    func stopwatchElapsed(at date: Date) -> TimeInterval {
        stopwatchAccumulated + (stopwatchStart.map { date.timeIntervalSince($0) } ?? 0)
    }

    func start() {
        Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.tick() }
            .store(in: &bag)
    }

    func add(minutes: Double, label: String? = nil) {
        let duration = minutes * 60
        let name = label ?? (minutes < 1 ? "\(Int(duration))s" : "\(Int(minutes)) min")
        timers.append(BlobTimer(label: name, duration: duration, endDate: Date().addingTimeInterval(duration)))
        save()
    }

    func togglePause(_ timer: BlobTimer) {
        guard let i = timers.firstIndex(where: { $0.id == timer.id }) else { return }
        if let remaining = timers[i].pausedRemaining {
            timers[i].endDate = Date().addingTimeInterval(remaining)
            timers[i].pausedRemaining = nil
        } else {
            timers[i].pausedRemaining = timers[i].remaining(at: Date())
        }
        save()
    }

    func cancel(_ timer: BlobTimer) {
        timers.removeAll { $0.id == timer.id }
        save()
    }

    func dismissRinging() {
        ringTask?.cancel()
        ringing = nil
    }

    func toggleStopwatch() {
        if let start = stopwatchStart {
            stopwatchAccumulated += Date().timeIntervalSince(start)
            stopwatchStart = nil
        } else {
            stopwatchStart = Date()
        }
    }

    func resetStopwatch() {
        stopwatchStart = nil
        stopwatchAccumulated = 0
    }

    private func tick() {
        let now = Date()
        guard let done = timers.first(where: { !$0.isPaused && $0.remaining(at: now) <= 0 }) else { return }
        timers.removeAll { $0.id == done.id }
        save()
        ringing = done
        if Prefs.bool(Prefs.timerSound) { NSSound(named: "Glass")?.play() }
        ringTask?.cancel()
        ringTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.ringing = nil
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: file),
              let saved = try? JSONDecoder().decode([BlobTimer].self, from: data) else { return }
        let now = Date()
        var keep: [BlobTimer] = []
        var justFinished: BlobTimer?
        for timer in saved {
            if timer.isPaused || timer.remaining(at: now) > 0 {
                keep.append(timer)
            } else if now.timeIntervalSince(timer.endDate) < 60, justFinished == nil {
                justFinished = timer
            }
        }
        timers = keep
        if keep.count != saved.count { save() }
        if let justFinished {
            ringing = justFinished
            if Prefs.bool(Prefs.timerSound) { NSSound(named: "Glass")?.play() }
            ringTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { return }
                self?.ringing = nil
            }
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(timers) { try? data.write(to: file, options: .atomic) }
    }

}
