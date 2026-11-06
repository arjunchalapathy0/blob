import SwiftUI

/// Every feature service, created once and shared by all notch windows.
@MainActor
final class Services: ObservableObject {
    static let shared = Services()

    let notices: NoticeCenter
    let nowPlaying: NowPlayingService
    let hud: SystemHUDService
    let shelf: ShelfStore
    let clipboard: ClipboardService
    let calendar: CalendarService
    let timers: TimerService
    let claude: ClaudeService
    let tools: QuickToolsService
    let stats: StatsService
    let camera: CameraService
    let updates: UpdateService
    let ask: AskService
    let lock: LockService
    let phoneBridge = PhoneBridge()
    let agent: AgentService

    private init() {
        let notices = NoticeCenter()
        self.notices = notices
        nowPlaying = NowPlayingService()
        hud = SystemHUDService(notices: notices)
        shelf = ShelfStore()
        clipboard = ClipboardService(notices: notices)
        calendar = CalendarService()
        timers = TimerService(notices: notices)
        claude = ClaudeService(notices: notices)
        tools = QuickToolsService(notices: notices)
        stats = StatsService(notices: notices)
        camera = CameraService()
        updates = UpdateService(notices: notices)
        ask = AskService()
        lock = LockService()
        agent = AgentService(notices: notices, ask: ask)
    }

    func start() {
        nowPlaying.start()
        hud.start()
        clipboard.start()
        calendar.start()
        timers.start()
        claude.start()
        stats.start()
        updates.start()
        lock.start()
        agent.start()
        phoneBridge.start(claude: claude, ask: ask, agent: agent)
    }
}

extension View {
    func withServices(_ s: Services) -> some View {
        self
            .environmentObject(s)
            .environmentObject(s.notices)
            .environmentObject(s.nowPlaying)
            .environmentObject(s.hud)
            .environmentObject(s.shelf)
            .environmentObject(s.clipboard)
            .environmentObject(s.calendar)
            .environmentObject(s.timers)
            .environmentObject(s.claude)
            .environmentObject(s.tools)
            .environmentObject(s.stats)
            .environmentObject(s.camera)
            .environmentObject(s.updates)
            .environmentObject(s.ask)
            .environmentObject(s.lock)
            .environmentObject(s.phoneBridge)
            .environmentObject(s.agent)
    }
}
