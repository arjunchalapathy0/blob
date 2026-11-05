import SwiftUI

@main
struct BlobPhoneApp: App {
    @StateObject private var timers = TimerStore()
    @StateObject private var ask = AskModel()
    @StateObject private var link = MacLink()
    @StateObject private var calendar = CalendarStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView {
                TimersScreen().tabItem { Label("Timers", systemImage: "timer") }
                AskScreen().tabItem { Label("Ask", systemImage: "eye") }
                ClaudeScreen().tabItem { Label("Claude", systemImage: "sparkle") }
                CalendarScreen().tabItem { Label("Today", systemImage: "calendar") }
            }
            .tint(Theme.ink)
            .background(Theme.surface.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .environmentObject(timers)
            .environmentObject(ask)
            .environmentObject(link)
            .environmentObject(calendar)
            .onAppear { link.start() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    timers.sweep()
                    calendar.refresh()
                }
            }
        }
    }
}
