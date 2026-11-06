import AVFoundation

/// Records 16 kHz mono WAV from the current input device (the Mirror tab's mic picker sets it).
@MainActor
final class VoiceRecorder {
    private var recorder: AVAudioRecorder?
    private var startedAt: Date?

    static var permission: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .audio) }

    static func requestPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    func start() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("blob-voice-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let r = try AVAudioRecorder(url: url, settings: settings)
        r.isMeteringEnabled = true
        guard r.record() else { throw NSError(domain: "Blob", code: 1, userInfo: [NSLocalizedDescriptionKey: "The microphone didn’t start."]) }
        recorder = r
        startedAt = Date()
    }

    /// 0...1, for the little level bars.
    var level: Float {
        guard let recorder else { return 0 }
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        return max(0, min(1, (db + 50) / 45))
    }

    /// Stops and returns the file and how long it was.
    func stop() -> (url: URL, duration: TimeInterval)? {
        guard let recorder, let startedAt else { return nil }
        recorder.stop()
        self.recorder = nil
        self.startedAt = nil
        return (recorder.url, Date().timeIntervalSince(startedAt))
    }

    func cancel() {
        if let result = stop() { try? FileManager.default.removeItem(at: result.url) }
    }
}
