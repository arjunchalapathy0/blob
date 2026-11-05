import Foundation
import UserNotifications

struct PhoneTimer: Identifiable, Codable, Equatable {
    var id = UUID()
    var label: String
    var duration: TimeInterval
    var end: Date
    var activityID: String?
}

/// Timers that live in the Dynamic Island and ring with a notification, even when the app is closed.
@MainActor
final class TimerStore: ObservableObject {
    @Published private(set) var timers: [PhoneTimer] = []
    private let key = "phoneTimers"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([PhoneTimer].self, from: data) {
            timers = saved.filter { $0.end > Date().addingTimeInterval(-60) }
        }
    }

    func add(minutes: Double) {
        let duration = minutes * 60
        let label = minutes < 60 ? "\(Int(minutes)) min" : "\(Int(minutes / 60)) h"
        let end = Date().addingTimeInterval(duration)
        var timer = PhoneTimer(label: label, duration: duration, end: end)
        timer.activityID = IslandManager.start(
            kind: .timer,
            state: .init(mood: Mood.idle.rawValue, title: "Timer", detail: label, endDate: end),
            staleDate: end)
        timers.append(timer)
        scheduleNotification(for: timer)
        save()
    }

    func cancel(_ timer: PhoneTimer) {
        IslandManager.end(id: timer.activityID)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timer.id.uuidString])
        timers.removeAll { $0.id == timer.id }
        save()
    }

    /// Clears finished timers; their island shows "Done" for a little while, then goes away.
    func sweep() {
        let now = Date()
        for timer in timers where timer.end <= now {
            IslandManager.end(id: timer.activityID, after: 60)
        }
        let before = timers.count
        timers.removeAll { $0.end <= now.addingTimeInterval(-5) }
        if timers.count != before { save() }
    }

    private func scheduleNotification(for timer: PhoneTimer) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Time’s up"
            content.body = timer.label
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, timer.end.timeIntervalSinceNow), repeats: false)
            center.add(UNNotificationRequest(identifier: timer.id.uuidString, content: content, trigger: trigger))
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(timers) { UserDefaults.standard.set(data, forKey: key) }
    }
}
