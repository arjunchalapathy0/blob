import Foundation
import WhisperKit

/// Speech to text on this Mac with Whisper (WhisperKit, Core ML). The model downloads once
/// (about 150 MB) and then everything runs offline.
actor Transcriber {
    static let model = "base.en"

    private var pipe: WhisperKit?
    private var loading: Task<WhisperKit, Error>?

    var isReady: Bool { pipe != nil }

    @discardableResult
    func prepare() async throws -> WhisperKit {
        if let pipe { return pipe }
        if let loading { return try await loading.value }
        let task = Task { try await WhisperKit(WhisperKitConfig(model: Self.model, verbose: false)) }
        loading = task
        do {
            let ready = try await task.value
            pipe = ready
            loading = nil
            return ready
        } catch {
            loading = nil
            throw error
        }
    }

    func transcribe(_ url: URL) async throws -> String {
        let whisper = try await prepare()
        let results = try await whisper.transcribe(audioPath: url.path)
        let text = results.map(\.text).joined(separator: " ")
        // Whisper marks silence and noise like "[BLANK_AUDIO]" or "(wind blowing)".
        let cleaned = text.replacingOccurrences(of: #"\[[^\]]*\]|\([^)]*\)"#, with: "", options: .regularExpression)
        return cleaned.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
