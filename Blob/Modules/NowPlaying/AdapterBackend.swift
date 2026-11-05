import Foundation

/// Now Playing through ungive/mediaremote-adapter. `/usr/bin/perl` is entitled to use
/// MediaRemote, so it loads the adapter framework and streams JSON lines to us.
final class AdapterBackend: NowPlayingBackend {
    let name = "MediaRemote adapter"
    var onUpdate: ((TrackInfo?) -> Void)?

    private let script: String
    private let framework: String
    private let queue = DispatchQueue(label: "blob.nowplaying.adapter")
    private var process: Process?
    private var buffer = Data()
    private var state: [String: Any] = [:]
    private var stopped = false
    private var restartDelay: TimeInterval = 1

    init?() {
        guard let script = Bundle.main.path(forResource: "mediaremote-adapter", ofType: "pl"),
              let frameworks = Bundle.main.privateFrameworksPath else { return nil }
        let framework = (frameworks as NSString).appendingPathComponent("MediaRemoteAdapter.framework")
        guard FileManager.default.fileExists(atPath: framework) else { return nil }
        self.script = script
        self.framework = framework
    }

    func start() { queue.async { self.launch() } }

    func stop() {
        queue.async {
            self.stopped = true
            self.process?.terminate()
            self.process = nil
        }
    }

    func send(_ command: MediaCommand) { run(["send", String(command.rawValue)]) }

    func seek(to seconds: Double) { run(["seek", String(Int64(seconds * 1_000_000))]) }

    // MARK: - Stream

    private func launch() {
        guard !stopped else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [script, framework, "stream"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        out.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            self?.queue.async { self?.consume(data) }
        }
        p.terminationHandler = { [weak self] _ in
            guard let self else { return }
            out.fileHandleForReading.readabilityHandler = nil
            self.queue.asyncAfter(deadline: .now() + self.restartDelay) {
                self.restartDelay = min(self.restartDelay * 2, 30)
                self.launch()
            }
        }
        do {
            try p.run()
            process = p
            buffer.removeAll()
        } catch {
            queue.asyncAfter(deadline: .now() + 5) { self.launch() }
        }
    }

    private func consume(_ data: Data) {
        guard !data.isEmpty else { return }
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<newline)
            buffer.removeSubrange(buffer.startIndex...newline)
            handle(line)
        }
    }

    private func handle(_ line: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { return }
        if let type = object["type"] as? String, type != "data" { return }
        restartDelay = 1
        let payload = object["payload"] as? [String: Any] ?? [:]
        if object["diff"] as? Bool == true {
            for (key, value) in payload {
                if value is NSNull { state.removeValue(forKey: key) } else { state[key] = value }
            }
        } else {
            state = payload
        }
        onUpdate?(Self.parse(state))
    }

    static func parse(_ d: [String: Any]) -> TrackInfo? {
        guard let title = d["title"] as? String, !title.isEmpty else { return nil }
        func number(_ key: String) -> Double? { (d[key] as? NSNumber)?.doubleValue }

        var t = TrackInfo()
        t.title = title
        t.artist = d["artist"] as? String ?? ""
        t.album = d["album"] as? String ?? ""
        t.duration = number("duration") ?? 0
        t.elapsed = number("elapsedTime") ?? 0
        t.rate = number("playbackRate") ?? 1
        t.isPlaying = (d["playing"] as? Bool) ?? ((number("playbackRate") ?? 0) > 0)
        t.bundleID = (d["parentApplicationBundleIdentifier"] as? String) ?? (d["bundleIdentifier"] as? String)
        t.timestamp = parseDate(d["timestamp"]) ?? Date()
        if let art = d["artworkData"] as? String { t.artworkData = Data(base64Encoded: art) }
        return t
    }

    private static func parseDate(_ value: Any?) -> Date? {
        if let n = value as? NSNumber {
            let v = n.doubleValue
            if v > 1e14 { return Date(timeIntervalSince1970: v / 1_000_000) }  // microseconds
            if v > 1e11 { return Date(timeIntervalSince1970: v / 1000) }       // milliseconds
            return Date(timeIntervalSince1970: v)
        }
        if let s = value as? String {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
        }
        return nil
    }

    // MARK: - Commands

    private func run(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [script, framework] + args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
    }
}
