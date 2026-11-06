import Foundation

/// Runs the Claude Code CLI (`claude`) so Blob can use the user's Claude subscription instead of
/// an API key. Claude Code must be installed and signed in (`claude`, then `/login`).
enum ClaudeCLI {
    /// Folders where installers put `claude`, also added to PATH so a Node-based install finds `node`.
    static var searchDirectories: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(home)/.local/bin", "\(home)/.claude/local", "/opt/homebrew/bin", "/usr/local/bin",
                "\(home)/.npm-global/bin", "\(home)/.volta/bin", "\(home)/.bun/bin", "/usr/bin", "/bin",
                "/usr/sbin", "/sbin"]
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
        case reset              // a new assistant message started: drop earlier text (e.g. "Let me look…")
        case text(String)       // streamed text
        case final(String)      // the finished answer
        case failure(String)
        case step(String)       // a tool call, in plain words ("Opening Safari")
        case session(String)    // Claude Code session id, for follow-ups
    }

    // MARK: - Modes

    /// Read-only question about an image file.
    static func ask(cli: String, imagePath: String, question: String, workingDirectory: URL,
                    context: String = "what is on their screen right now",
                    onEvent: @escaping @MainActor (Event) -> Void) async throws {
        try await run(cli: cli, workingDirectory: workingDirectory, arguments: [
            "-p", "The image is at \(imagePath). Look at it with the Read tool, then answer: \(question)",
            "--allowedTools", "Read",
            "--max-turns", "4",
            "--append-system-prompt",
            "You are answering inside Blob, a small helper app. The user is asking about \(context). "
                + "Answer directly and briefly: a few sentences or a short list. Refer to things by what "
                + "they say on screen. Don't mention the file or that you read it. Use Markdown sparingly.",
        ], label: question, onEvent: onEvent)
    }

    /// Does what the user asked on this Mac: shell, AppleScript, apps, files, the web, and the screen.
    static func agent(cli: String, request: String, resume: String?,
                      onEvent: @escaping @MainActor (Event) -> Void) async throws {
        var args = [
            "-p", request,
            "--allowedTools", "Bash,Read,Write,Edit,Glob,Grep,WebFetch,WebSearch",
            "--disallowedTools", "Bash(sudo:*),Bash(rm -rf:*),Bash(rm -fr:*),Bash(diskutil:*)",
            "--permission-mode", "acceptEdits",
            "--max-turns", "40",
            "--append-system-prompt", agentPrompt,
        ]
        if let resume { args += ["--resume", resume] }
        try await run(cli: cli, workingDirectory: FileManager.default.homeDirectoryForCurrentUser,
                      arguments: args, label: request, onEvent: onEvent)
    }

    private static let agentPrompt = """
    You are Blob, the user's assistant living in their Mac's notch. They speak or type short requests \
    (often transcribed speech, so expect small transcription errors) and you carry them out on this Mac.

    How to act on the Mac:
    - Shell commands with Bash. `open -a "App"` opens apps; `open URL` opens links and files.
    - AppleScript with `osascript` to control apps (Music, Safari, Finder, Notes, Reminders, Calendar, Mail...) \
    and System Events to click, type keystrokes and read UI. Accessibility access is granted.
    - `shortcuts run "Name"` runs the user's Shortcuts.
    - To see the screen, run `screencapture -x "$TMPDIR/blob-screen.png"` and then Read that file.

    Rules:
    - Act directly and quickly; don't ask clarifying questions unless the request is truly ambiguous.
    - Before anything destructive or hard to undo (deleting or overwriting files, emptying the trash, \
    quitting apps with unsaved work), anything sent to other people (messages, emails, posts), purchases, \
    or changing security/privacy settings: do NOT do it. Say exactly what you would do and ask the user \
    to confirm; their next request continues this conversation.
    - Never use sudo, and never touch passwords or credentials.
    - When finished, reply in one or two short plain sentences saying what you did or found. The reply \
    is shown in a tiny notch: no Markdown headings, no lists unless asked.
    """

    // MARK: - Runner

    private static func run(cli: String, workingDirectory: URL, arguments: [String], label: String,
                            onEvent: @escaping @MainActor (Event) -> Void) async throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cli)
        p.currentDirectoryURL = workingDirectory
        p.arguments = arguments + [
            "--output-format", "stream-json", "--verbose", "--include-partial-messages",
            // Don't run anyone's hooks (including Blob's own) for these runs.
            "--settings", #"{"disableAllHooks": true}"#,
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

        let log = Log(label: label)
        var gotResult = false
        var sentSession = false
        try await withTaskCancellationHandler {
            for try await line in out.fileHandleForReading.bytes.lines {
                log.append(line)
                for event in parse(line) {
                    switch event {
                    case .final, .failure: gotResult = true
                    case .session: if sentSession { continue }; sentSession = true
                    default: break
                    }
                    await onEvent(event)
                }
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
        init(label: String) { text = "\(Date()) request: \(label)\n" }
        func append(_ line: String) { text += line + "\n" }
        func save() {
            let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Blob", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? text.write(to: dir.appendingPathComponent("ask.log"), atomically: true, encoding: .utf8)
        }
    }

    private static func parse(_ line: String) -> [Event] {
        guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { return [] }
        var events: [Event] = []
        if let session = obj["session_id"] as? String, !session.isEmpty { events.append(.session(session)) }
        switch obj["type"] as? String {
        case "stream_event":
            guard let event = obj["event"] as? [String: Any] else { break }
            switch event["type"] as? String {
            case "message_start":
                events.append(.reset)
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any], delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String { events.append(.text(text)) }
            default:
                break
            }
        case "assistant":
            let content = (obj["message"] as? [String: Any])?["content"] as? [[String: Any]] ?? []
            for block in content where block["type"] as? String == "tool_use" {
                events.append(.step(stepLabel(tool: block["name"] as? String ?? "",
                                              input: block["input"] as? [String: Any] ?? [:])))
            }
        case "result":
            let result = obj["result"] as? String ?? ""
            if obj["is_error"] as? Bool == true {
                let subtype = obj["subtype"] as? String ?? ""
                events.append(.failure(friendly(result.isEmpty ? subtype : result)))
            } else if !result.isEmpty {
                events.append(.final(result))
            }
        default:
            break
        }
        return events
    }

    /// Plain words for a tool call, shown in the notch while the agent works.
    static func stepLabel(tool: String, input: [String: Any]) -> String {
        func file(_ key: String = "file_path") -> String {
            ((input[key] as? String) ?? "").split(separator: "/").last.map(String.init) ?? "a file"
        }
        switch tool {
        case "Bash":
            let command = (input["command"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            if command.contains("screencapture") { return "Looking at your screen" }
            if let description = input["description"] as? String, !description.isEmpty { return description }
            if command.hasPrefix("osascript") { return "Controlling an app" }
            if command.hasPrefix("open ") { return "Opening something" }
            if command.hasPrefix("shortcuts") { return "Running a shortcut" }
            return "Running a command"
        case "Read":
            let path = input["file_path"] as? String ?? ""
            return path.contains("blob-screen") ? "Looking at your screen" : "Reading \(file())"
        case "Write", "Edit", "MultiEdit": return "Editing \(file())"
        case "Glob", "Grep": return "Searching files"
        case "WebSearch": return "Searching the web"
        case "WebFetch": return "Reading a web page"
        default: return tool
        }
    }

    private static func friendly(_ message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("login") || lower.contains("api key") || lower.contains("authenticat") {
            return "Claude Code isn’t signed in. Run claude in Terminal and type /login."
        }
        if lower.contains("error_max_turns") { return "That took too many steps, so I stopped." }
        if lower.contains("limit") { return "You’ve hit your Claude usage limit for now." }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Claude Code stopped unexpectedly." : String(trimmed.prefix(200))
    }
}
