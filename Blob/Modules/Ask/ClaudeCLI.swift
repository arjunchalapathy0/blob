import Foundation

/// Runs the Claude Code CLI (`claude`) so Ask can use the user's Claude subscription
/// instead of an API key. Claude Code must be installed and signed in (`claude`, then `/login`).
enum ClaudeCLI {
    /// Folders where installers put `claude`, also added to PATH so a Node-based install finds `node`.
    static var searchDirectories: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(home)/.local/bin", "\(home)/.claude/local", "/opt/homebrew/bin", "/usr/local/bin",
                "\(home)/.npm-global/bin", "\(home)/.volta/bin", "\(home)/.bun/bin", "/usr/bin"]
    }

    /// Path to `claude`, or nil if it isn't installed. Checks the usual folders, then asks
    /// the login shell (which knows the user's PATH).
    static func locate() -> String? {
        let fm = FileManager.default
        for dir in searchDirectories {
            let path = (dir as NSString).appendingPathComponent("claude")
            if fm.isExecutableFile(atPath: path) { return path }
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-ilc", "command -v claude"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        p.standardInput = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return nil }
        p.waitUntilExit()
        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let path = text.split(separator: "\n").map(String.init).last { $0.hasPrefix("/") }
        return path.flatMap { fm.isExecutableFile(atPath: $0) ? $0 : nil }
    }

    enum Event {
        case reset            // a new assistant message started: drop earlier text (e.g. "Let me look…")
        case text(String)     // streamed text
        case final(String)    // the finished answer
        case failure(String)
    }

    /// Asks Claude Code about a screenshot file and streams events.
    static func ask(cli: String, imagePath: String, question: String, workingDirectory: URL,
                    onEvent: @escaping @MainActor (Event) -> Void) async throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cli)
        p.currentDirectoryURL = workingDirectory
        p.arguments = [
            "-p", "A screenshot of my screen is at \(imagePath). Look at it with the Read tool, then answer: \(question)",
            "--output-format", "stream-json", "--verbose", "--include-partial-messages",
            "--allowedTools", "Read",
            "--max-turns", "4",
            // Don't run anyone's hooks (including Blob's own) for these quick questions.
            "--settings", #"{"disableAllHooks": true}"#,
            "--append-system-prompt",
            "You are answering inside Blob, a small helper in the Mac's notch. The user is asking about what is on their "
                + "screen right now. Answer directly and briefly: a few sentences or a short list. Refer to things by what "
                + "they say on screen. Don't mention the file or that you read it. Use Markdown sparingly.",
        ]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = (searchDirectories + [env["PATH"] ?? ""]).joined(separator: ":")
        env["BLOB_ASK"] = "1" // tells Blob's own Claude Code hooks to ignore this run
        p.environment = env
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        p.standardInput = FileHandle.nullDevice
        try p.run()

        let log = Log(question: question)
        var gotResult = false
        try await withTaskCancellationHandler {
            for try await line in out.fileHandleForReading.bytes.lines {
                log.append(line)
                guard let event = parse(line) else { continue }
                if case .final = event { gotResult = true }
                if case .failure = event { gotResult = true }
                await onEvent(event)
            }
        } onCancel: {
            p.terminate()
        }
        while p.isRunning { try await Task.sleep(for: .milliseconds(50)) }
        let stderr = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        log.append("exit \(p.terminationStatus)\n" + stderr)
        log.save()
        if !gotResult {
            // Hook chatter isn't the real problem; show the rest.
            let useful = stderr.split(separator: "\n").filter { !$0.contains("hook") }.joined(separator: "\n")
            await onEvent(.failure(friendly(useful.isEmpty ? "Claude Code exited without an answer (code \(p.terminationStatus))." : useful)))
        }
    }

    /// Keeps the last run's raw output in ~/Library/Logs/Blob/ask.log for troubleshooting.
    private final class Log {
        private var text: String
        init(question: String) { text = "\(Date()) question: \(question)\n" }
        func append(_ line: String) { text += line + "\n" }
        func save() {
            let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Blob", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? text.write(to: dir.appendingPathComponent("ask.log"), atomically: true, encoding: .utf8)
        }
    }

    private static func parse(_ line: String) -> Event? {
        guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { return nil }
        switch obj["type"] as? String {
        case "stream_event":
            guard let event = obj["event"] as? [String: Any] else { return nil }
            switch event["type"] as? String {
            case "message_start":
                return .reset
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any], delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String { return .text(text) }
            default:
                break
            }
        case "result":
            let result = obj["result"] as? String ?? ""
            if obj["is_error"] as? Bool == true {
                let subtype = obj["subtype"] as? String ?? ""
                return .failure(friendly(result.isEmpty ? subtype : result))
            }
            return result.isEmpty ? nil : .final(result)
        default:
            break
        }
        return nil
    }

    private static func friendly(_ message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("login") || lower.contains("api key") || lower.contains("authenticat") {
            return "Claude Code isn’t signed in. Run claude in Terminal and type /login."
        }
        if lower.contains("limit") { return "You’ve hit your Claude usage limit for now." }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Claude Code stopped unexpectedly." : String(trimmed.prefix(200))
    }
}
