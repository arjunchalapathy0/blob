import SwiftUI
import Combine

/// State for one notch on one screen: phase (closed, peek, open), what the wings show,
/// and how the character feels.
@MainActor
final class NotchViewModel: ObservableObject {
    enum Phase: Equatable { case closed, peek, open }

    @Published private(set) var phase: Phase = .closed
    @Published var tab: ModuleID = .nowPlaying
    @Published private(set) var activity: LiveActivity = .none
    @Published private(set) var mood: Mood = .idle
    @Published private(set) var look: CGSize = .zero
    @Published var isDropTargeted = false {
        didSet { if isDropTargeted { cancelClose() } }
    }

    let screen: NSScreen
    let notch: CGSize
    let hasNotch: Bool
    let services: Services

    /// Called after any change that affects the hit area, so the window can update mouse passthrough.
    var onLayoutChange: (() -> Void)?

    private var bag = Set<AnyCancellable>()
    private var hoverTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var lastInteraction = Date()
    private var wakeUntil: Date?

    init(screen: NSScreen, services: Services) {
        self.screen = screen
        self.services = services
        self.notch = NotchGeometry.closedSize(on: screen)
        self.hasNotch = NotchGeometry.hasNotch(screen)
        self.tab = ModuleID.enabled.first ?? .nowPlaying

        let changes: [AnyPublisher<Void, Never>] = [
            services.notices.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            services.nowPlaying.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            services.timers.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            services.claude.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            services.calendar.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            Timer.publish(every: 1, on: .main, in: .common).autoconnect().map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(changes)
            .receive(on: DispatchQueue.main) // objectWillChange fires before the value changes
            .sink { [weak self] in self?.recompute() }
            .store(in: &bag)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if !self.tab.isEnabled, let first = ModuleID.enabled.first { self.tab = first }
                self.objectWillChange.send()
                self.recompute()
            }
            .store(in: &bag)
    }

    // MARK: - Geometry

    var openSize: CGSize { CGSize(width: 680, height: notch.height + 178) }

    var closedSize: CGSize {
        CGSize(width: notch.width + 2 * activity.wingWidth, height: notch.height)
    }

    /// Size of the notch body (without the top ears).
    var bodySize: CGSize {
        switch phase {
        case .open: return openSize
        case .peek:
            let c = closedSize
            return CGSize(width: max(c.width, notch.width + 28), height: notch.height + 30)
        case .closed: return closedSize
        }
    }

    var topRadius: CGFloat { phase == .open ? 14 : 6 }
    var bottomRadius: CGFloat {
        switch phase {
        case .open: 30
        case .peek: 18
        case .closed: activity == .none ? 10 : 12
        }
    }

    /// The area (in screen coordinates) that should receive the mouse.
    func hitRect() -> NSRect {
        let size = bodySize
        let width = size.width + 2 * topRadius
        var rect = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - size.height,
                          width: width, height: size.height)
        switch phase {
        case .closed: rect = rect.insetBy(dx: -6, dy: -3)
        case .peek: rect = rect.insetBy(dx: -4, dy: -4)
        case .open: rect = rect.insetBy(dx: -12, dy: -12)
        }
        return rect
    }

    /// Where a file drag should open the shelf.
    func dropZone() -> NSRect {
        let width = max(notch.width + 160, 360)
        return NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - notch.height - 70,
                      width: width, height: notch.height + 70)
    }

    // MARK: - Phase

    func open(tab: ModuleID? = nil) {
        if let tab, tab.isEnabled { self.tab = tab }
        cancelHover(); cancelClose()
        lastInteraction = Date()
        guard phase != .open else { return }
        if Prefs.bool(Prefs.haptics) {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        setPhase(.open)
    }

    func close() {
        cancelHover(); cancelClose()
        guard phase != .closed else { return }
        setPhase(.closed)
    }

    private func setPhase(_ new: Phase) {
        guard new != phase else { return }
        if new == .peek, Date().timeIntervalSince(lastInteraction) > 600 {
            wakeUntil = Date().addingTimeInterval(0.9) // stays sleepy for a moment, then wakes up
        }
        phase = new
        recompute()
        onLayoutChange?()
    }

    /// When pinned, the open notch stays open after the cursor leaves or you click elsewhere.
    var isPinned: Bool { Prefs.bool(Prefs.stayOpen) }

    func togglePin() {
        UserDefaults.standard.set(!isPinned, forKey: Prefs.stayOpen)
        objectWillChange.send()
        lastInteraction = Date()
        // Unpinning with the cursor already away should let it close.
        mouseMoved(to: NSEvent.mouseLocation)
    }

    func select(_ tab: ModuleID) {
        withAnimation(Springs.snap) { self.tab = tab }
        lastInteraction = Date()
    }

    // MARK: - Mouse

    func mouseMoved(to point: NSPoint) {
        let inside = hitRect().contains(point)
        if phase != .closed { updateLook(point) } // the character is only visible when peeking or open
        switch phase {
        case .closed:
            inside ? scheduleHover() : cancelHover()
        case .peek:
            if !inside { cancelHover(); setPhase(.closed) }
        case .open:
            if inside || isDropTargeted || isPinned { cancelClose() } else { scheduleClose() }
        }
        if inside { lastInteraction = Date() }
    }

    private func scheduleHover() {
        guard hoverTask == nil else { return }
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            guard let self, !Task.isCancelled else { return }
            self.setPhase(.peek)
            guard Prefs.bool(Prefs.openOnHover) else { return }
            try? await Task.sleep(for: .seconds(max(0.05, Prefs.double(Prefs.hoverDelay))))
            guard !Task.isCancelled, self.phase == .peek else { return }
            self.open()
        }
    }

    private func cancelHover() { hoverTask?.cancel(); hoverTask = nil }

    private func scheduleClose() {
        guard closeTask == nil else { return }
        closeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(320))
            guard let self, !Task.isCancelled, !self.isDropTargeted, !self.isPinned else { return }
            self.closeTask = nil
            self.close()
        }
    }

    private func cancelClose() { closeTask?.cancel(); closeTask = nil }

    private func updateLook(_ p: NSPoint) {
        let center: CGPoint
        switch phase {
        case .open: center = CGPoint(x: screen.frame.midX - openSize.width / 2 + 28, y: screen.frame.maxY - notch.height / 2)
        default: center = CGPoint(x: screen.frame.midX, y: screen.frame.maxY - notch.height - 14)
        }
        let new = CGSize(width: max(-1, min(1, (p.x - center.x) / 220)),
                         height: max(-1, min(1, -(p.y - center.y) / 160)))
        if abs(new.width - look.width) > 0.02 || abs(new.height - look.height) > 0.02 { look = new }
    }

    // MARK: - Drop

    func drop(_ providers: [NSItemProvider]) -> Bool {
        guard ModuleID.shelf.isEnabled else { return false }
        services.shelf.add(providers: providers)
        tab = .shelf
        return true
    }

    // MARK: - Activity & mood

    private func recompute() {
        let s = services
        var next: LiveActivity = .none
        if let notice = s.notices.current {
            next = .notice(notice)
        } else if ModuleID.timers.isEnabled, s.timers.ringing != nil {
            next = .timerDone
        } else if ModuleID.claude.isEnabled, s.claude.aggregate == .waiting {
            next = .claude(.waiting)
        } else if ModuleID.timers.isEnabled, s.timers.primary != nil {
            next = .timer
        } else if ModuleID.claude.isEnabled, s.claude.aggregate == .working {
            next = .claude(.working)
        } else if ModuleID.calendar.isEnabled, s.calendar.imminent != nil {
            next = .event
        } else if ModuleID.nowPlaying.isEnabled, s.nowPlaying.isPlaying {
            next = .music
        }
        if next != activity {
            withAnimation(Springs.snap) { activity = next }
            onLayoutChange?()
        }

        let newMood = resolveMood()
        if newMood != mood { mood = newMood }
    }

    private func resolveMood() -> Mood {
        let s = services
        if let wake = wakeUntil, wake > Date() { return .sleepy }
        if s.timers.ringing != nil || s.claude.aggregate == .waiting { return .alarmed }
        if s.claude.aggregate == .working { return .busy }
        if s.nowPlaying.isPlaying { return .happy }
        if phase == .peek { return .curious }
        if Date().timeIntervalSince(lastInteraction) > 600 { return .sleepy }
        return .idle
    }
}
