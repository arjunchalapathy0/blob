import AppKit
import Security

/// Updates Blob from its source folder: git pull, rebuild with the same signing team,
/// then replace the installed app and relaunch. Building locally with your own
/// certificate keeps macOS permissions (Accessibility, Calendar, Camera) across updates.
@MainActor
final class UpdateService: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(count: Int, summary: String)
        case updating
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastChecked: Date?

    private let notices: NoticeCenter
    private var timer: Timer?

    static let sourcePathKey = "updateSourcePath"

    init(notices: NoticeCenter) { self.notices = notices }

    var isAvailable: Bool { if case .available = state { return true }; return false }
    var isUpdating: Bool { state == .updating }

    /// The source folder: the one chosen in Settings, else the folder this copy was built from.
    var sourceURL: URL? {
        let custom = UserDefaults.standard.string(forKey: Self.sourcePathKey)
        let built = Bundle.main.object(forInfoDictionaryKey: "BlobSourcePath") as? String
        for path in [custom, built].compactMap({ $0 }) where !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.isExecutableFile(atPath: url.appendingPathComponent("scripts/update.sh").path) {
                return url
            }
        }
        return nil
    }

    func setSource(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: Self.sourcePathKey)
        objectWillChange.send()
        Task { await check() }
    }

    func start() {
        Task {
            try? await Task.sleep(for: .seconds(15))
            await check()
        }
        let t = Timer(timeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func check() async {
        guard state != .updating, state != .checking else { return }
        guard let source = sourceURL else {
            state = .failed("Choose Blob’s source folder in Settings.")
            return
        }
        state = .checking
        let result = await Self.run(source, ["check"])
        lastChecked = Date()
        guard result.status == 0 else {
            state = .failed(Self.firstLine(result.output, fallback: "Couldn’t reach the repository."))
            return
        }
        let values = Self.parse(result.output)
        let behind = Int(values["behind"] ?? "0") ?? 0
        let wasAvailable = isAvailable
        state = behind > 0 ? .available(count: behind, summary: values["summary"] ?? "") : .upToDate
        if behind > 0, !wasAvailable {
            notices.message("arrow.down.circle.fill", "Update ready", duration: 3)
        }
    }

    func update() {
        guard !isUpdating, let source = sourceURL else { return }
        state = .updating
        notices.message("arrow.triangle.2.circlepath", "Updating…", duration: 900)
        Task {
            let team = Self.teamID()
            Self.saveTeam(team, in: source)
            let result = await Self.run(source, ["build", team ?? ""])
            let app = Self.parse(result.output)["app"]
            guard result.status == 0, let app, FileManager.default.fileExists(atPath: app) else {
                state = .failed(Self.firstLine(result.output, fallback: "Build failed."))
                notices.message("exclamationmark.triangle.fill", "Update failed", duration: 3)
                return
            }
            install(app, from: source)
        }
    }

    /// Hands off to a detached script that waits for Blob to quit, swaps the app and reopens it.
    private func install(_ newApp: String, from source: URL) {
        let current = Bundle.main.bundlePath
        let destination = current.hasPrefix("/Applications/") ? current : "/Applications/Blob.app"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [source.appendingPathComponent("scripts/update.sh").path, "install", newApp, destination,
                       String(ProcessInfo.processInfo.processIdentifier)]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            NSApp.terminate(nil)
        } catch {
            state = .failed("Couldn’t install: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    /// Keeps the signing team in Config/Local.xcconfig so regenerating the project doesn't reset it.
    private static func saveTeam(_ team: String?, in source: URL) {
        guard let team, !team.isEmpty else { return }
        let file = source.appendingPathComponent("Config/Local.xcconfig")
        guard !FileManager.default.fileExists(atPath: file.path) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? "// Your Apple team for signing. Not committed.\nDEVELOPMENT_TEAM = \(team)\n"
            .write(to: file, atomically: true, encoding: .utf8)
    }

    private static func run(_ source: URL, _ args: [String]) async -> (status: Int32, output: String) {
        // Run a copy (next to the original, so it finds the project): `git pull` may rewrite
        // update.sh while it's running, and bash reads scripts as it goes.
        let original = source.appendingPathComponent("scripts/update.sh")
        let copy = source.appendingPathComponent("scripts/.update-run-\(UUID().uuidString).sh")
        let script = (try? FileManager.default.copyItem(at: original, to: copy)) != nil ? copy : original
        defer { if script == copy { try? FileManager.default.removeItem(at: copy) } }
        return await withCheckedContinuation { continuation in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = [script.path] + args
            p.currentDirectoryURL = source
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            p.terminationHandler = { proc in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: (proc.terminationStatus, String(decoding: data, as: UTF8.self)))
            }
            do { try p.run() } catch {
                continuation.resume(returning: (-1, error.localizedDescription))
            }
        }
    }

    private static func parse(_ output: String) -> [String: String] {
        var values: [String: String] = [:]
        for line in output.split(separator: "\n") {
            guard let eq = line.firstIndex(of: "=") else { continue }
            values[String(line[..<eq])] = String(line[line.index(after: eq)...])
        }
        return values
    }

    private static func firstLine(_ output: String, fallback: String) -> String {
        output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? fallback
    }

    /// The signing team of the running app, so the new build is signed the same way.
    static func teamID() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess
        else { return nil }
        return (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
    }
}
