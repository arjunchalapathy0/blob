import Combine
import Foundation
import Network

/// Shares Claude Code status with Blob on iPhone over the local network (Bonjour), and answers
/// the phone's Ask questions with Claude Code (the user's subscription).
/// Off unless "Show on iPhone" is on; a phone must send the pairing code before it gets anything.
@MainActor
final class PhoneBridge: ObservableObject {
    @Published private(set) var pairingCode: String
    @Published private(set) var pairedCount = 0

    private final class Client {
        let connection: NWConnection
        var buffer = Data()
        var authorized = false
        var tasks: [String: Task<Void, Never>] = [:]
        init(_ connection: NWConnection) { self.connection = connection }
    }

    private var listener: NWListener?
    private var clients: [ObjectIdentifier: Client] = [:]
    private var host = Host.current().localizedName ?? "Mac"
    private var sessions: [Bridge.Session] = []
    private var bag = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "blob.phonebridge")
    private weak var ask: AskService?
    private weak var agent: AgentService?
    private var failedCodes: [Date] = []

    private static let codeKey = "phonePairingCode"

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.codeKey), saved.count == 6 {
            pairingCode = saved
        } else {
            pairingCode = Self.newCode()
            UserDefaults.standard.set(pairingCode, forKey: Self.codeKey)
        }
    }

    func start(claude: ClaudeService, ask: AskService, agent: AgentService) {
        self.ask = ask
        self.agent = agent
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

    /// Makes a new code and disconnects every paired phone.
    func resetCode() {
        pairingCode = Self.newCode()
        UserDefaults.standard.set(pairingCode, forKey: Self.codeKey)
        clients.values.forEach { $0.connection.cancel() }
        clients.removeAll()
        pairedCount = 0
    }

    private static func newCode() -> String { String(format: "%06d", Int.random(in: 0...999_999)) }

    private func apply() {
        if Prefs.bool(Prefs.phoneBridge) { startListener() } else { stopListener() }
    }

    private func startListener() {
        guard listener == nil, let l = try? NWListener(using: .tcp) else { return }
        l.service = NWListener.Service(name: host, type: Bridge.serviceType)
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
        clients.values.forEach { $0.connection.cancel() }
        clients.removeAll()
        pairedCount = 0
    }

    private func accept(_ connection: NWConnection) {
        let client = Client(connection)
        let key = ObjectIdentifier(connection)
        clients[key] = client
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                Task { @MainActor in self?.remove(key) }
            default:
                break
            }
        }
        connection.start(queue: queue)
        receive(client, key: key)
    }

    private func remove(_ key: ObjectIdentifier) {
        guard let client = clients.removeValue(forKey: key) else { return }
        client.tasks.values.forEach { $0.cancel() }
        pairedCount = clients.values.filter(\.authorized).count
    }

    private func receive(_ client: Client, key: ObjectIdentifier) {
        client.connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, complete, error in
            Task { @MainActor in
                guard let self else { return }
                if let data {
                    client.buffer.append(data)
                    for line in Bridge.takeLines(from: &client.buffer) { self.handle(line, from: client) }
                }
                if complete || error != nil { client.connection.cancel() } else { self.receive(client, key: key) }
            }
        }
    }

    private func handle(_ line: Data, from client: Client) {
        guard let message = Bridge.decode(line) else { return }
        switch message {
        case .hello(let code):
            // Five wrong codes in ten minutes locks pairing for the rest of that window.
            failedCodes.removeAll { Date().timeIntervalSince($0) > 600 }
            guard failedCodes.count < 5, code == pairingCode else {
                if code != pairingCode { failedCodes.append(Date()) }
                send(.denied, to: client)
                client.connection.cancel()
                return
            }
            client.authorized = true
            pairedCount = clients.values.filter(\.authorized).count
            send(.snapshot(host: host, sessions: sessions), to: client)

        case .ask(let id, let question, let image):
            guard client.authorized else { send(.denied, to: client); return }
            client.tasks[id] = Task { await self.answer(id: id, question: question, image: image, for: client) }

        case .task(let id, let text):
            guard client.authorized else { send(.denied, to: client); return }
            func reply(_ event: Bridge.AskEvent, _ text: String = "") { send(.askEvent(id: id, event: event, text: text), to: client) }
            guard Prefs.bool(Prefs.phoneTasks) else {
                reply(.error, "Turn on “Let iPhone ask this Mac to do things” in Blob’s Settings on your Mac.")
                return
            }
            guard let agent, !agent.isBusy else {
                reply(.error, "Blob on your Mac is busy. Try again in a moment.")
                return
            }
            var sentFinal = false
            agent.run(text) { event in
                switch event {
                case .reset: reply(.reset)
                case .text(let t): reply(.text, t)
                case .step(let s): reply(.step, s)
                case .final(let t): sentFinal = true; reply(.final, t)
                case .failure(let m): if !sentFinal { reply(.error, m) }
                case .session: break
                }
            }

        default:
            break
        }
    }

    private func answer(id: String, question: String, image: String, for client: Client) async {
        func reply(_ event: Bridge.AskEvent, _ text: String = "") { send(.askEvent(id: id, event: event, text: text), to: client) }
        guard let cli = ask?.cliPath else {
            reply(.error, "Claude Code isn’t installed on your Mac.")
            return
        }
        guard let jpeg = Data(base64Encoded: image) else {
            reply(.error, "The image didn’t arrive intact.")
            return
        }
        do {
            let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Blob/Ask", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent("phone-\(UUID().uuidString).jpg")
            try jpeg.write(to: file)
            defer { try? FileManager.default.removeItem(at: file) }
            var sentFinal = false
            try await ClaudeCLI.ask(cli: cli, imagePath: file.path, question: question, workingDirectory: dir,
                                    context: "an image the user shared from their iPhone, usually a screenshot") { event in
                switch event {
                case .reset: reply(.reset)
                case .text(let t): reply(.text, t)
                case .final(let t): sentFinal = true; reply(.final, t)
                case .failure(let m): if !sentFinal { reply(.error, m) }
                default: break
                }
            }
        } catch is CancellationError {
        } catch {
            reply(.error, error.localizedDescription)
        }
        client.tasks[id] = nil
    }

    private func publish(_ claudeSessions: [ClaudeSession]) {
        sessions = claudeSessions.map {
            Bridge.Session(id: $0.id, project: $0.project, state: $0.state.rawValue, detail: $0.detail, updated: $0.updated)
        }
        for client in clients.values where client.authorized {
            send(.snapshot(host: host, sessions: sessions), to: client)
        }
    }

    private func send(_ message: Bridge.Message, to client: Client) {
        client.connection.send(content: Bridge.encode(message), completion: .contentProcessed { _ in })
    }
}
