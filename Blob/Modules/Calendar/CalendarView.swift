import SwiftUI
import EventKit

struct CalendarView: View {
    @EnvironmentObject private var calendar: CalendarService

    var body: some View {
        if !calendar.isAuthorized {
            EmptyState(text: "See what’s next", detail: "Blob needs calendar access to show your events.",
                       mood: .curious, actionTitle: "Allow access") { calendar.requestAccess() }
        } else {
            HStack(alignment: .top, spacing: 18) {
                TimelineView(.everyMinute) { ctx in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(ctx.date.formatted(.dateTime.weekday(.wide)))
                            .font(Theme.font(12, .semibold)).foregroundStyle(Theme.secondary)
                        Text(ctx.date.formatted(.dateTime.day()))
                            .font(Theme.font(46, .bold)).foregroundStyle(Theme.ink)
                        Text(ctx.date.formatted(.dateTime.month(.wide)))
                            .font(Theme.font(12)).foregroundStyle(Theme.tertiary)
                    }
                }
                .frame(width: 96, alignment: .leading)

                if calendar.events.isEmpty {
                    EmptyState(text: "Nothing scheduled", detail: "Enjoy the quiet.", mood: .sleepy)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 4) {
                            ForEach(calendar.events, id: \.calendarItemIdentifier) { event in
                                EventRow(event: event)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct EventRow: View {
    let event: EKEvent
    @EnvironmentObject private var calendar: CalendarService

    var body: some View {
        let now = Date()
        let ongoing = event.startDate <= now && event.endDate > now
        HStack(spacing: 10) {
            Capsule()
                .fill(ongoing ? Theme.ink : Theme.tertiary)
                .frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "Untitled").font(Theme.font(12, .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Text(timeText).font(Theme.font(10)).foregroundStyle(Theme.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            if let url = CalendarService.meetingURL(for: event) {
                PillButton(title: "Join", symbol: "video.fill", prominent: ongoing || calendar.imminent == event) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { calendar.open(event) }
    }

    private var timeText: String {
        if event.isAllDay { return "All day" }
        let start = event.startDate.formatted(date: Calendar.current.isDateInToday(event.startDate) ? .omitted : .abbreviated,
                                              time: .shortened)
        let end = event.endDate.formatted(date: .omitted, time: .shortened)
        var text = "\(start) – \(end)"
        if let location = event.location, !location.isEmpty, !location.hasPrefix("http") { text += " · \(location)" }
        return text
    }
}
