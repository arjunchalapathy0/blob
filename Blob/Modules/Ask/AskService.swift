import AppKit
import ScreenCaptureKit

/// Ask about your screen: captures the display (without Blob itself), sends it to Claude
/// with your question, and streams the answer back.
@MainActor
final class AskService: ObservableObject {
    @Published var question = ""
    @Published private(set) var askedQuestion = ""
    @Published private(set) var answer = ""
    @Published private(set) var snapshot: NSImage?
    @Published private(set) var isBusy = false
    @Published private(set) var error: String?
    @Published private(set) var hasKey = Keychain.read() != nil
    @Published private(set) var canCapture = CGPreflightScreenCaptureAccess()

    private var task: Task<Void, Never>?

    static let model = "claude-opus-5-5"

    /// Keep the notch open while typing, waiting or reading.
    var holdsOpen: Bool { isBusy || !question.isEmpty }

    var hasResult: Bool { !answer.isEmpty || error != nil || isBusy }

    func setKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { Keychain.delete() } else { Keychain.save(trimmed) }
        hasKey = Keychain.read() != nil
    }

    func requestScreenAccess() {
        CGRequestScreenCaptureAccess()
        canCapture = CGPreflightScreenCaptureAccess()
        if !canCapture,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func refreshPermissions() {
        canCapture = CGPreflightScreenCaptureAccess()
        hasKey = Keychain.read() != nil
    }

    func clear() {
        cancel()
        answer = ""
        askedQuestion = ""
        snapshot = nil
        error = nil
    }

    func cancel() {
        task?.cancel()
        task = nil
        isBusy = false
    }

    func ask(on screen: NSScreen) {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !isBusy, let key = Keychain.read() else { return }
        cancel()
        question = ""
        askedQuestion = q
        answer = ""
        error = nil
        isBusy = true

        task = Task {
            do {
                let image = try await Self.capture(screen)
                snapshot = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                guard let jpeg = NSBitmapImageRep(cgImage: image)
                    .representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
                    throw AskError.message("Couldn’t encode the screenshot.")
                }
                try await stream(question: q, jpeg: jpeg, key: key)
            } catch is CancellationError {
            } catch AskError.message(let text) {
                error = text
            } catch {
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
            isBusy = false
        }
    }

    // MARK: - Screen

    private static func capture(_ screen: NSScreen) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let screenID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        guard let display = content.displays.first(where: { $0.displayID == screenID }) ?? content.displays.first else {
            throw AskError.message("No display to capture.")
        }
        let me = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: me, exceptingWindows: [])
        let config = SCStreamConfiguration()
        // Long edge around 1568 px keeps text legible while staying fast and cheap.
        let scale = min(2, 1568 / CGFloat(max(display.width, display.height)))
        config.width = Int(CGFloat(display.width) * scale)
        config.height = Int(CGFloat(display.height) * scale)
        config.showsCursor = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    // MARK: - Claude

    private func stream(question: String, jpeg: Data, key: String) async throws {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 16000,
            "stream": true,
            "fallbacks": "default",
            "output_config": ["effort": "medium"],
            "system": """
            You are Blob, a small assistant that lives in the Mac's notch. The user is asking about \
            what is on their screen right now; a screenshot is attached. Answer directly and briefly: \
            a few sentences or a short list. Refer to things by what they say on screen. Use Markdown sparingly.
            """,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image",
                     "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()]],
                    ["type": "text", "text": question],
                ],
            ]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard status == 200 else {
            var text = ""
            for try await line in bytes.lines { text += line }
            throw AskError.message(Self.apiError(text, status: status))
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let data = payload.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            switch event["type"] as? String {
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String {
                    answer += text
                }
            case "message_delta":
                let stop = (event["delta"] as? [String: Any])?["stop_reason"] as? String
                if stop == "refusal" {
                    answer = ""
                    throw AskError.message("Claude declined to answer this one.")
                }
            case "error":
                let message = (event["error"] as? [String: Any])?["message"] as? String
                throw AskError.message(message ?? "Something went wrong.")
            default:
                break
            }
        }
    }

    private static func apiError(_ body: String, status: Int) -> String {
        if let data = body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = (json["error"] as? [String: Any])?["message"] as? String {
            return status == 401 ? "Your API key was rejected." : message
        }
        return "Request failed (\(status))."
    }
}

private enum AskError: Error { case message(String) }
