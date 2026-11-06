import ActivityKit
import Foundation
import Network

/// Finds Blob on your Mac over Wi-Fi, pairs with the code shown in the Mac's Settings,
/// receives Claude Code status, and relays Ask questions so they use your Claude subscription.
@MainActor
final class MacLink: ObservableObject {
    enum Status: Equatable { case searching, needsCode(String), connected(String) }

    @Published private(set) var status: Status = .searching
    @Published private(set) var sessions: [Bridge.Session] = []

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var macName = "Mac"
    private var buffer = Data()
    private var activityID: String?
    private var endedDoneKey: String?
    private var lastStates: [String: String] = [:]
    private var askHandlers: [String: (Bridge.AskEvent, String) -> Void] = [:]

    private static let codeKey = "macPairingCode"

    var isConnected: Bool { if case .connected = status { return true }; return false }

    var pairingCode: String { UserDefaults.standard.string(forKey: Self.codeKey) ?? "" }

    func start() {
        guard browser == nil else { return }
        let b = NWBrowser(for: .bonjour(type: Bridge.serviceType, domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in self?.found(results) }
        }
        b.start(queue: .main)
        browser = b
    }

    /// Saves the code from the Mac's Settings and reconnects with it.
    func pair(code: String) {
        UserDefaults.standard.set(code.filter(\.isNumber), forKey: Self.codeKey)
        connection?.cancel()
    }

    // MARK: - Connection

    private func found(_ results: Set<NWBrowser.Result>) {
        guard connection == nil, let result = results.first else { return }
        if case let .service(serviceName, _, _, _) = result.endpoint { macName = serviceName }
        let c = NWConnection(to: result.endpoint, using: .tcp)
        c.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .ready:
                    if self.pairingCode.isEmpty {
                        self.status = .needsCode(self.macName)
                    } else {
                        self.status = .connected(self.macName)
                        self.send(.hello(code: self.pairingCode))
                    }
                    self.receive()
                case .failed, .cancelled:
                    self.drop()
                default:
                    break
                }
            }
        }
        connection = c
        c.start(queue: .main)
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, complete, error in
            Task { @MainActor in
                guard let self else { return }
                if let data {
                    self.buffer.append(data)
                    for line in Bridge.takeLines(from: &self.buffer) { self.handle(line) }
                }
                if complete || error != nil { self.drop() } else { self.receive() }
            }
        }
    }

    private func handle(_ line: Data) {
        switch Bridge.decode(line) {
        case .snapshot(_, let list)?:
            status = .connected(macName)
            sessions = list.sorted { $0.updated > $1.updated }
            updateIsland()
        case .denied?:
            UserDefaults.standard.removeObject(forKey: Self.codeKey)
            status = .needsCode(macName)
        case .askEvent(let id, let event, let text)?:
            askHandlers[id]?(event, text)
            if event == .final || event == .error { askHandlers[id] = nil }
        default:
            break
        }
    }

    private func send(_ message: Bridge.Message) {
        connection?.send(content: Bridge.encode(message), completion: .contentProcessed { _ in })
    }

    private func drop() {
        connection?.cancel()
        connection = nil
        buffer.removeAll()
        for handler in askHandlers.values { handler(.error, "Lost the connection to your Mac.") }
        askHandlers.removeAll()
        if case .needsCode = status {} else { status = .searching }
        Task {
            try? await Task.sleep(for: .seconds(2))
            if let results = browser?.browseResults { found(results) }
        }
    }

    // MARK: - Ask through the Mac

    /// Sends an image and question to the Mac; events arrive on `onEvent` until final or error.
    func ask(question: String, jpeg: Data, onEvent: @escaping (Bridge.AskEvent, String) -> Void) -> String? {
        guard isConnected, connection != nil else { return nil }
        let id = UUID().uuidString
        askHandlers[id] = onEvent
        send(.ask(id: id, question: question, image: jpeg.base64EncodedString()))
        return id
    }

    func cancelAsk(_ id: String) { askHandlers[id] = nil }

    /// Asks Blob on the Mac to do something (it runs Claude Code there).
    func task(_ text: String, onEvent: @escaping (Bridge.AskEvent, String) -> Void) -> String? {
        guard isConnected, connection != nil else { return nil }
        let id = UUID().uuidString
        askHandlers[id] = onEvent
        send(.task(id: id, text: text))
        return id
    }

    // MARK: - Lock Screen / Dynamic Island

    var showsInIsland: Bool {
        get { UserDefaults.standard.object(forKey: "claudeIsland") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "claudeIsland")
            objectWillChange.send()
            updateIsland()
        }
    }

    private func updateIsland() {
        // Banners for sessions that just started waiting or just finished.
        var alert: (title: String, body: String)?
        for s in sessions where lastStates[s.id] != nil && lastStates[s.id] != s.state {
            if s.state == "waiting" { alert = ("\(s.project) needs you", s.detail) }
            else if s.state == "done", alert == nil { alert = ("\(s.project) is done", "Claude finished.") }
        }
        lastStates = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.state) })

        let recent = sessions.filter { $0.state != "idle" && Date().timeIntervalSince($0.updated) < 30 * 60 }
        let focus = recent.first { $0.state == "waiting" } ?? recent.first { $0.state == "working" } ?? recent.first
        guard showsInIsland, let focus else {
            IslandManager.end(id: activityID)
            activityID = nil
            return
        }
        // A finished session shows "Done" once, then stays gone.
        let doneKey = "\(focus.id)@\(focus.updated.timeIntervalSince1970)"
        if focus.state == "done", doneKey == endedDoneKey { return }
        let mood: Mood = switch focus.state {
        case "waiting": .alarmed
        case "working": .busy
        default: .happy
        }
        let state = BlobActivityAttributes.ContentState(mood: mood.rawValue, title: focus.project,
                                                        detail: focus.detail, endDate: nil)
        let alertConfig = alert.map {
            AlertConfiguration(title: LocalizedStringResource(stringLiteral: $0.title),
                               body: LocalizedStringResource(stringLiteral: $0.body), sound: .default)
        }
        if let id = activityID, IslandManager.activities(of: .claude).contains(where: { $0.id == id }) {
            IslandManager.update(id: id, state: state, alert: alertConfig)
        } else {
            activityID = IslandManager.start(kind: .claude, state: state)
            if let alertConfig, let id = activityID { IslandManager.update(id: id, state: state, alert: alertConfig) }
        }
        if focus.state == "done" {
            IslandManager.end(id: activityID, after: 120)
            activityID = nil
            endedDoneKey = doneKey
        }
    }
}
