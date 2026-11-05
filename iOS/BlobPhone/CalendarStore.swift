import EventKit
import Foundation

@MainActor
final class CalendarStore: ObservableObject {
    @Published private(set) var events: [EKEvent] = []
    @Published private(set) var authorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
    @Published private(set) var islandEventID: String?
    private var activityID: String?
    private let store = EKEventStore()

    func requestAccess() async {
        _ = try? await store.requestFullAccessToEvents()
        refresh()
    }

    func refresh() {
        authorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        guard authorized else { return }
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now
        events = store.events(matching: store.predicateForEvents(withStart: now, end: end, calendars: nil))
            .filter { !$0.isAllDay && $0.status != .canceled }
            .sorted { ($0.startDate as Date) < ($1.startDate as Date) }
    }

    /// Counts down to the event's start in the Dynamic Island.
    func showInIsland(_ event: EKEvent) {
        IslandManager.end(id: activityID)
        let start: Date = event.startDate
        activityID = IslandManager.start(
            kind: .event,
            state: .init(mood: Mood.curious.rawValue, title: event.title ?? "Event",
                         detail: event.location ?? "", endDate: start),
            staleDate: start)
        islandEventID = activityID == nil ? nil : event.calendarItemIdentifier
    }

    func hideFromIsland() {
        IslandManager.end(id: activityID)
        activityID = nil
        islandEventID = nil
    }
}
