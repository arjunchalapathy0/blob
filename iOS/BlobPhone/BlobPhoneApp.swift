import SwiftUI

@main
struct BlobPhoneApp: App {
    @StateObject private var timers = TimerStore()
    @StateObject private var ask = AskModel()
    @StateObject private var link = MacLink()
    @StateObject private var calendar = CalendarStore()
    @StateObject private var mac = MacTaskModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeScreen().tabItem { Label("Blob", systemImage: "capsule.fill") }
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
            .environmentObject(mac)
            .toolbarBackground(Theme.surface, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .onAppear {
                ask.link = link
                mac.link = link
                link.start()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    timers.sweep()
                    calendar.refresh()
                }
            }
        }
    }
}
