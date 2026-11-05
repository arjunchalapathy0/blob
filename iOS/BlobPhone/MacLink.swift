import Foundation
import Network

/// Finds Blob on your Mac over Wi-Fi and receives Claude Code status from it.
@MainActor
final class MacLink: ObservableObject {
    enum Status: Equatable { case searching, connected(String) }

    @Published private(set) var status: Status = .searching
    @Published private(set) var sessions: [Bridge.Session] = []

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var buffer = Data()
    private var activityID: String?
    private var endedDoneKey: String?

    func start() {
        guard browser == nil else { return }
        let b = NWBrowser(for: .bonjour(type: Bridge.serviceType, domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in self?.found(results) }
        }
        b.start(queue: .main)
        browser = b
    }

    private func found(_ results: Set<NWBrowser.Result>) {
        guard connection == nil, let result = results.first else { return }
        var name = "Mac"
        if case let .service(serviceName, _, _, _) = result.endpoint { name = serviceName }
        let c = NWConnection(to: result.endpoint, using: .tcp)
        c.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .ready:
                    self.status = .connected(name)
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
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, complete, error in
            Task { @MainActor in
                guard let self else { return }
                if let data { self.consume(data) }
                if complete || error != nil { self.drop() } else { self.receive() }
            }
        }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<newline)
            buffer.removeSubrange(buffer.startIndex...newline)
            if let snapshot = Bridge.decode(line) {
                sessions = snapshot.sessions.sorted { $0.updated > $1.updated }
                updateIsland()
            }
        }
    }

    private func drop() {
        connection?.cancel()
        connection = nil
        buffer.removeAll()
        status = .searching
        // Look again shortly; the browser keeps running.
        Task {
            try? await Task.sleep(for: .seconds(2))
            if let results = browser?.browseResults { found(results) }
        }
    }

    // MARK: - Dynamic Island

    var showsInIsland: Bool {
        get { UserDefaults.standard.object(forKey: "claudeIsland") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "claudeIsland")
            objectWillChange.send()
            updateIsland()
        }
    }

    private func updateIsland() {
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
        if let id = activityID, IslandManager.activities(of: .claude).contains(where: { $0.id == id }) {
            IslandManager.update(id: id, state: state)
        } else {
            activityID = IslandManager.start(kind: .claude, state: state)
        }
        if focus.state == "done" {
            IslandManager.end(id: activityID, after: 120)
            activityID = nil
            endedDoneKey = doneKey
        }
    }
}
