import AppKit
import Combine

struct BlobTimer: Identifiable, Equatable {
    let id = UUID()
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

    init(notices: NoticeCenter) { self.notices = notices }

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
    }

    func togglePause(_ timer: BlobTimer) {
        guard let i = timers.firstIndex(where: { $0.id == timer.id }) else { return }
        if let remaining = timers[i].pausedRemaining {
            timers[i].endDate = Date().addingTimeInterval(remaining)
            timers[i].pausedRemaining = nil
        } else {
            timers[i].pausedRemaining = timers[i].remaining(at: Date())
        }
    }

    func cancel(_ timer: BlobTimer) {
        timers.removeAll { $0.id == timer.id }
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
        ringing = done
        if Prefs.bool(Prefs.timerSound) { NSSound(named: "Glass")?.play() }
        ringTask?.cancel()
        ringTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.ringing = nil
        }
    }

}
