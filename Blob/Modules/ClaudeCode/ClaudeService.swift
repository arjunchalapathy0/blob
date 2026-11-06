import AppKit
import Combine

enum ClaudeState: String, Equatable, Codable {
    case idle, working, waiting, done
}

struct ClaudeSession: Identifiable, Equatable {
    let id: String
    var cwd: String
    var state: ClaudeState
    var detail: String
    var updated: Date

    var project: String {
        cwd.isEmpty ? "Session" : (cwd as NSString).lastPathComponent
    }
}

/// Watches ~/.blob/claude/ for status files written by the Claude Code hooks.
@MainActor
final class ClaudeService: ObservableObject {
    @Published private(set) var sessions: [ClaudeSession] = []
    @Published private(set) var hooksInstalled = ClaudeHookInstaller.isInstalled
    @Published private(set) var hooksNeedUpdate = ClaudeHookInstaller.needsUpdate
    @Published var lastError: String?

    private let notices: NoticeCenter
    private var source: DispatchSourceFileSystemObject?
    private var bag = Set<AnyCancellable>()

    init(notices: NoticeCenter) { self.notices = notices }

    /// The state that matters most across all sessions.
    var aggregate: ClaudeState {
        if sessions.contains(where: { $0.state == .waiting }) { return .waiting }
        if sessions.contains(where: { $0.state == .working }) { return .working }
        return sessions.isEmpty ? .idle : .done
    }

    func start() {
        let dir = ClaudeHookCLI.directory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fd = open(dir.path, O_EVTONLY)
        if fd >= 0 {
            let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
            src.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.reload() }
            }
            src.setCancelHandler { close(fd) }
            src.resume()
            source = src
        }
        // If Blob moved (e.g. a new build in Applications), point the hooks at this copy.
        if ClaudeHookInstaller.needsUpdate {
            try? ClaudeHookInstaller.install()
            refreshInstallState()
        }
        // Backup poll, and ages out stale sessions.
        Timer.publish(every: 5, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.reload() }
            .store(in: &bag)
        reload()
    }

    func installHooks() {
        do {
            try ClaudeHookInstaller.install()
            lastError = nil
            notices.message("checkmark", "Hooks installed")
        } catch {
            lastError = error.localizedDescription
        }
        refreshInstallState()
    }

    func uninstallHooks() {
        do {
            try ClaudeHookInstaller.uninstall()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refreshInstallState()
    }

    func refreshInstallState() {
        hooksInstalled = ClaudeHookInstaller.isInstalled
        hooksNeedUpdate = ClaudeHookInstaller.needsUpdate
    }

    func dismiss(_ session: ClaudeSession) {
        try? FileManager.default.removeItem(at: ClaudeHookCLI.directory.appendingPathComponent("\(session.id).json"))
        reload()
    }

    func openTerminal(for session: ClaudeSession) {
        guard !session.cwd.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: session.cwd))
    }

    private func reload() {
        let fm = FileManager.default
        let dir = ClaudeHookCLI.directory
        let now = Date()
        var loaded: [ClaudeSession] = []

        for url in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let stateRaw = json["state"] as? String, var state = ClaudeState(rawValue: stateRaw) else { continue }
            let updated = Date(timeIntervalSince1970: (json["updated"] as? NSNumber)?.doubleValue ?? 0)
            let age = now.timeIntervalSince(updated)
            if age > 12 * 3600 { try? fm.removeItem(at: url); continue }
            // A session that went silent mid-turn probably crashed or was killed.
            if state == .working, age > 20 * 60 { state = .idle }
            loaded.append(ClaudeSession(id: url.deletingPathExtension().lastPathComponent,
                                        cwd: json["cwd"] as? String ?? "",
                                        state: state,
                                        detail: json["detail"] as? String ?? "",
                                        updated: updated))
        }
        loaded.sort { $0.updated > $1.updated }
        announceTransitions(from: sessions, to: loaded)
        if loaded != sessions { sessions = loaded }
    }

    private func announceTransitions(from old: [ClaudeSession], to new: [ClaudeSession]) {
        let before = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0.state) })
        for s in new where before[s.id] != nil && before[s.id] != s.state {
            switch s.state {
            case .done:
                notices.message("checkmark.circle.fill", "Done · \(s.project)", duration: 3)
                if Prefs.bool(Prefs.claudeSounds) { NSSound(named: "Glass")?.play() }
            case .waiting:
                if Prefs.bool(Prefs.claudeSounds) { NSSound(named: "Tink")?.play() }
            default:
                break
            }
        }
    }
}
