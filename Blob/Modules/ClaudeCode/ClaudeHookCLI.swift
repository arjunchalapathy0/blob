import Foundation

/// Runs when Claude Code calls `Blob --claude-hook`. Reads the hook JSON from stdin and
/// writes one small status file per session to ~/.blob/claude/. The app watches that folder.
/// Never prints and always exits 0, so it cannot get in Claude Code's way.
enum ClaudeHookCLI {
    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".blob/claude", isDirectory: true)
    }

    static func run() {
        // Ask runs Claude Code itself; don't show those runs as sessions.
        if ProcessInfo.processInfo.environment["BLOB_ASK"] != nil { return }
        let input = FileHandle.standardInput.readDataToEndOfFile()
        guard let json = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any],
              let sessionID = json["session_id"] as? String, !sessionID.isEmpty else { return }

        let event = json["hook_event_name"] as? String ?? ""
        let safeID = String(sessionID.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }.prefix(80))
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("\(safeID).json")

        if event == "SessionEnd" {
            try? fm.removeItem(at: file)
            return
        }

        let previous = (try? Data(contentsOf: file))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let previousState = previous?["state"] as? String

        let state: String
        let detail: String
        switch event {
        case "SessionStart":
            state = "idle"; detail = "Ready"
        case "UserPromptSubmit":
            state = "working"; detail = "Thinking"
        case "PreToolUse":
            state = "working"; detail = toolLabel(json["tool_name"] as? String, input: json["tool_input"] as? [String: Any])
        case "PostToolUse":
            state = "working"; detail = "Thinking"
        case "Notification":
            let message = json["message"] as? String ?? "Needs your input"
            // The "waiting for your input" reminder after a finished turn is not a new request.
            if previousState == "done" || previousState == "idle",
               message.lowercased().contains("waiting for your input") { return }
            state = "waiting"; detail = message
        case "Stop":
            state = "done"; detail = "Finished"
        default:
            return
        }

        let record: [String: Any] = [
            "session_id": sessionID,
            "cwd": json["cwd"] as? String ?? "",
            "state": state,
            "detail": detail,
            "updated": Date().timeIntervalSince1970,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: record) {
            try? data.write(to: file, options: .atomic)
        }
    }

    private static func toolLabel(_ tool: String?, input: [String: Any]?) -> String {
        let name = tool ?? "tool"
        func file() -> String? {
            (input?["file_path"] as? String).map { ($0 as NSString).lastPathComponent }
        }
        switch name {
        case "Read": return file().map { "Reading \($0)" } ?? "Reading"
        case "Edit", "MultiEdit", "Write": return file().map { "Editing \($0)" } ?? "Editing"
        case "Bash": return "Running a command"
        case "Grep", "Glob": return "Searching"
        case "WebFetch", "WebSearch": return "Browsing"
        case "Task", "Agent": return "Delegating"
        case "TodoWrite": return "Planning"
        default: return name.hasPrefix("mcp__") ? "Using \(name.split(separator: "__").dropFirst().first ?? "a tool")" : name
        }
    }
}
