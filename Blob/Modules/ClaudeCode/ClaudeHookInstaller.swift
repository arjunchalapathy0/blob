import Foundation

/// Adds or removes Blob's entries in ~/.claude/settings.json, leaving everything else as is.
enum ClaudeHookInstaller {
    static let events = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse",
                         "Notification", "Stop", "SessionEnd"]
    static let marker = "--claude-hook"

    static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }

    static var command: String {
        let exe = Bundle.main.executablePath ?? "/Applications/Blob.app/Contents/MacOS/Blob"
        return "\"\(exe)\" \(marker)"
    }

    static var isInstalled: Bool {
        guard let hooks = load()["hooks"] as? [String: Any] else { return false }
        return hooks.values.contains { value in
            (value as? [[String: Any]] ?? []).contains { entry in
                (entry["hooks"] as? [[String: Any]] ?? []).contains { ($0["command"] as? String)?.contains(marker) == true }
            }
        }
    }

    /// True when the installed hook points at a different copy of Blob (e.g. the app moved).
    static var needsUpdate: Bool {
        guard isInstalled, let hooks = load()["hooks"] as? [String: Any] else { return false }
        let commands = hooks.values.flatMap { value in
            (value as? [[String: Any]] ?? []).flatMap { ($0["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String } }
        }
        return !commands.filter { $0.contains(marker) }.allSatisfy { $0 == command }
    }

    static func install() throws {
        var root = load()
        backupOnce()
        var hooks = strip(root["hooks"] as? [String: Any] ?? [:])
        for event in events {
            var list = hooks[event] as? [[String: Any]] ?? []
            var entry: [String: Any] = ["hooks": [["type": "command", "command": command, "timeout": 5]]]
            if event == "PreToolUse" || event == "PostToolUse" { entry["matcher"] = "*" }
            list.append(entry)
            hooks[event] = list
        }
        root["hooks"] = hooks
        try save(root)
    }

    static func uninstall() throws {
        var root = load()
        let hooks = strip(root["hooks"] as? [String: Any] ?? [:])
        if hooks.isEmpty { root.removeValue(forKey: "hooks") } else { root["hooks"] = hooks }
        try save(root)
    }

    private static func strip(_ hooks: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (event, value) in hooks {
            guard let list = value as? [[String: Any]] else { out[event] = value; continue }
            let cleaned: [[String: Any]] = list.compactMap { entry in
                var entry = entry
                let inner = (entry["hooks"] as? [[String: Any]] ?? []).filter {
                    ($0["command"] as? String)?.contains(marker) != true
                }
                guard !inner.isEmpty else { return nil }
                entry["hooks"] = inner
                return entry
            }
            if !cleaned.isEmpty { out[event] = cleaned }
        }
        return out
    }

    private static func load() -> [String: Any] {
        guard let data = try? Data(contentsOf: settingsURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object
    }

    private static func save(_ root: [String: Any]) throws {
        try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: settingsURL, options: .atomic)
    }

    private static func backupOnce() {
        let backup = settingsURL.appendingPathExtension("blob-backup")
        let fm = FileManager.default
        if fm.fileExists(atPath: settingsURL.path), !fm.fileExists(atPath: backup.path) {
            try? fm.copyItem(at: settingsURL, to: backup)
        }
    }
}
