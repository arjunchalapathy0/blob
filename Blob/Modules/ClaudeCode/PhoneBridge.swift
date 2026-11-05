import Combine
import Foundation
import Network

/// Shares Claude Code status with Blob on iPhone over the local network (Bonjour).
/// Off unless "Show on iPhone" is on in Settings.
@MainActor
final class PhoneBridge {
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var snapshot = Bridge.Snapshot(host: Host.current().localizedName ?? "Mac", sessions: [])
    private var bag = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "blob.phonebridge")

    func start(claude: ClaudeService) {
        claude.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in self?.publish(sessions) }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.apply() }
            .store(in: &bag)
        apply()
    }

    private func apply() {
        if Prefs.bool(Prefs.phoneBridge) { startListener() } else { stopListener() }
    }

    private func startListener() {
        guard listener == nil, let l = try? NWListener(using: .tcp) else { return }
        l.service = NWListener.Service(name: snapshot.host, type: Bridge.serviceType)
        l.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in self?.accept(connection) }
        }
        l.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                Task { @MainActor in
                    self?.stopListener()
                    try? await Task.sleep(for: .seconds(5))
                    self?.apply()
                }
            }
        }
        l.start(queue: queue)
        listener = l
    }

    private func stopListener() {
        listener?.cancel()
        listener = nil
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
    }

    private func accept(_ connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        connections[key] = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                Task { @MainActor in self?.connections.removeValue(forKey: key) }
            default:
                break
            }
        }
        connection.start(queue: queue)
        send(to: connection)
    }

    private func publish(_ sessions: [ClaudeSession]) {
        snapshot.sessions = sessions.map {
            Bridge.Session(id: $0.id, project: $0.project, state: $0.state.rawValue, detail: $0.detail, updated: $0.updated)
        }
        connections.values.forEach(send)
    }

    private func send(to connection: NWConnection) {
        connection.send(content: Bridge.encode(snapshot), completion: .contentProcessed { _ in })
    }
}
