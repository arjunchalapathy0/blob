import AppKit
import EventKit
import Combine

@MainActor
final class CalendarService: ObservableObject {
    @Published private(set) var status = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var events: [EKEvent] = []

    private let store = EKEventStore()
    private var bag = Set<AnyCancellable>()

    var isAuthorized: Bool { status == .fullAccess }

    func start() {
        NotificationCenter.default.publisher(for: .EKEventStoreChanged, object: store)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &bag)
        Timer.publish(every: 60, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &bag)
        refresh()
    }

    func requestAccess() {
        Task {
            _ = try? await store.requestFullAccessToEvents()
            status = EKEventStore.authorizationStatus(for: .event)
            if status != .fullAccess, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                NSWorkspace.shared.open(url)
            }
            refresh()
        }
    }

    func refresh() {
        status = EKEventStore.authorizationStatus(for: .event)
        guard isAuthorized, ModuleID.calendar.isEnabled else { events = []; return }
        let now = Date()
        let end = Calendar.current.date(byAdding: .hour, value: 36, to: Calendar.current.startOfDay(for: now)) ?? now
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-3600), end: end, calendars: nil)
        events = store.events(matching: predicate)
            .filter { ($0.endDate as Date) > now && $0.status != .canceled }
            .sorted { a, b in
                let ka = (a.isAllDay ? 0 : 1, a.startDate as Date)
                let kb = (b.isAllDay ? 0 : 1, b.startDate as Date)
                return ka < kb
            }
    }

    /// An event starting within 10 minutes, or one that started less than 5 minutes ago.
    var imminent: EKEvent? {
        let now = Date()
        return events.first {
            !$0.isAllDay && $0.startDate.timeIntervalSince(now) < 600 && now.timeIntervalSince($0.startDate) < 300
        }
    }

    func imminentLabel(at date: Date) -> String {
        guard let event = imminent else { return "" }
        let minutes = Int(ceil(event.startDate.timeIntervalSince(date) / 60))
        return minutes > 0 ? "in \(minutes)m" : "Now"
    }

    /// A video-call link found in the event's URL, location or notes.
    static func meetingURL(for event: EKEvent) -> URL? {
        let haystack = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }.joined(separator: " ")
        let pattern = #"https://[^\s<>"]*(zoom\.us|meet\.google\.com|teams\.microsoft\.com|teams\.live\.com|webex\.com|facetime\.apple\.com)[^\s<>"]*"#
        guard let range = haystack.range(of: pattern, options: .regularExpression) else { return nil }
        return URL(string: String(haystack[range]))
    }

    func open(_ event: EKEvent) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.open(url)
        }
    }
}
