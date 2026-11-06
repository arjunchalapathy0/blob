import AppKit
import Combine

/// Blob's voice agent: hold Right Option, speak, let go. Whisper transcribes on the Mac and
/// Claude Code (the user's subscription) carries the request out. Requests typed in the Ask tab
/// and sent from the paired iPhone go through the same path.
@MainActor
final class AgentService: ObservableObject {
    enum Phase: String, Equatable { case idle, listening, transcribing, working, done, failed }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var level: Float = 0
    @Published private(set) var request = ""
    @Published private(set) var reply = ""
    @Published private(set) var steps: [String] = []
    @Published private(set) var error: String?
    @Published private(set) var whisperStatus = "Downloads on first use (about 150 MB)"
    @Published private(set) var micAllowed = VoiceRecorder.permission == .authorized

    private let notices: NoticeCenter
    private weak var ask: AskService?
    private let key = VoiceKey()
    private let recorder = VoiceRecorder()
    let transcriber = Transcriber()
    private var levelTimer: AnyCancellable?
    private var task: Task<Void, Never>?
    private var sessionID: String?
    private var lastFinished: Date?
    private var bag = Set<AnyCancellable>()

    init(notices: NoticeCenter, ask: AskService) {
        self.notices = notices
        self.ask = ask
    }

    var isBusy: Bool { phase == .listening || phase == .transcribing || phase == .working }
    var currentStep: String { steps.last ?? (phase == .working ? "Thinking" : "") }
    var isAvailable: Bool { ask?.cliPath != nil }

    func start() {
        key.onBegin = { [weak self] in self?.beginListening() }
        key.onEnd = { [weak self] in self?.endListening() }
        key.onCancel = { [weak self] in self?.cancelListening() }
        applyPrefs()
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyPrefs() }
            .store(in: &bag)
        // Get Whisper ready in the background so the first request is quick.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard let self, Prefs.bool(Prefs.voiceKey) else { return }
            await self.warmUp()
        }
    }

    private func applyPrefs() {
        if Prefs.bool(Prefs.voiceKey) { key.start() } else { key.stop() }
    }

    func requestMic() {
        Task {
            micAllowed = await VoiceRecorder.requestPermission()
            if !micAllowed, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func warmUp() async {
        if await transcriber.isReady { whisperStatus = "Ready"; return }
        whisperStatus = "Downloading Whisper…"
        do {
            try await transcriber.prepare()
            whisperStatus = "Ready"
        } catch {
            whisperStatus = "Couldn’t load Whisper: \(error.localizedDescription)"
        }
    }

    // MARK: - Voice

    private func beginListening() {
        guard !isBusy || phase == .done || phase == .failed else { return }
        micAllowed = VoiceRecorder.permission == .authorized
        guard micAllowed else {
            requestMic()
            notices.message("mic.slash", "Allow the microphone", duration: 2.5)
            return
        }
        guard isAvailable else {
            notices.message("exclamationmark.triangle", "Install Claude Code", duration: 2.5)
            return
        }
        do {
            try recorder.start()
        } catch {
            fail(error.localizedDescription)
            return
        }
        phase = .listening
        levelTimer = Timer.publish(every: 1 / 20, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in guard let self else { return }; self.level = self.recorder.level }
    }

    private func endListening() {
        levelTimer = nil
        level = 0
        guard phase == .listening, let recording = recorder.stop() else { return }
        guard recording.duration > 0.4 else {
            try? FileManager.default.removeItem(at: recording.url)
            phase = .idle
            return
        }
        phase = .transcribing
        Task {
            defer { try? FileManager.default.removeItem(at: recording.url) }
            do {
                if !(await transcriber.isReady) { whisperStatus = "Downloading Whisper…" }
                let text = try await transcriber.transcribe(recording.url)
                whisperStatus = "Ready"
                guard !text.isEmpty else {
                    phase = .idle
                    notices.message("ear", "Didn’t catch that", duration: 1.8)
                    return
                }
                run(text)
            } catch {
                fail("Couldn’t transcribe: \(error.localizedDescription)")
            }
        }
    }

    private func cancelListening() {
        levelTimer = nil
        level = 0
        recorder.cancel()
        if phase == .listening { phase = .idle }
    }

    // MARK: - Agent

    /// Runs a request. `onEvent` also receives the stream (used to relay to the iPhone).
    func run(_ text: String, onEvent: ((ClaudeCLI.Event) -> Void)? = nil) {
        guard let cli = ask?.cliPath else {
            fail("Install Claude Code and sign in to let Blob do things.")
            onEvent?(.failure("Claude Code isn’t installed on your Mac."))
            return
        }
        task?.cancel()
        // Follow-ups within 10 minutes continue the same conversation ("yes, do it").
        let resume = lastFinished.map { Date().timeIntervalSince($0) < 600 } == true ? sessionID : nil
        request = text
        reply = ""
        steps = []
        error = nil
        phase = .working
        task = Task {
            var failure: String?
            do {
                try await ClaudeCLI.agent(cli: cli, request: text, resume: resume) { [weak self] event in
                    guard let self else { return }
                    onEvent?(event)
                    switch event {
                    case .reset: self.reply = ""
                    case .text(let t): self.reply += t
                    case .final(let t): self.reply = t
                    case .failure(let m): failure = m
                    case .step(let s): if self.steps.last != s { self.steps.append(s) }
                    case .session(let id): self.sessionID = id
                    }
                }
            } catch is CancellationError {
                phase = .idle
                return
            } catch {
                failure = error.localizedDescription
            }
            lastFinished = Date()
            if let failure, reply.isEmpty {
                fail(failure)
            } else {
                phase = .done
                notices.message("checkmark.circle.fill", Self.headline(reply), duration: 4)
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        if phase == .working { phase = .idle }
    }

    func newConversation() {
        sessionID = nil
        lastFinished = nil
        request = ""
        reply = ""
        steps = []
        error = nil
        if !isBusy { phase = .idle }
    }

    private func fail(_ message: String) {
        error = message
        phase = .failed
        notices.message("exclamationmark.triangle.fill", "Couldn’t do that", duration: 2.5)
    }

    /// First sentence, short enough for the notch.
    private static func headline(_ text: String) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        let sentence = flat.split(separator: ".", maxSplits: 1).first.map(String.init) ?? flat
        return sentence.count > 28 ? String(sentence.prefix(27)) + "…" : (sentence.isEmpty ? "Done" : sentence)
    }
}
