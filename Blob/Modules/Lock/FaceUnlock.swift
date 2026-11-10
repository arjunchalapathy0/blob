import AVFoundation
import CoreImage
import Foundation
import Vision

/// Webcam face unlock for Blob's private tabs.
///
/// Macs have no Face ID sensor and Apple has no face-matching API for apps, so this is a
/// convenience, not a security boundary:
/// - Setup saves a few Vision "feature prints" of your face (an image fingerprint, not a photo)
///   to ~/Library/Application Support/Blob/face.dat.
/// - Unlocking needs a face that's close to those prints AND a blink (eyes open → shut → open),
///   which stops a printed photo. A video of you could still pass, so Touch ID or the password
///   always stays available, and it only guards Blob's own tabs.
/// Everything runs on this Mac; frames are never saved or sent anywhere.
final class FaceUnlock: @unchecked Sendable {
    enum Failure: LocalizedError {
        case noCamera, cameraDenied, noFace, notYou, timedOut, notSetUp
        var errorDescription: String? {
            switch self {
            case .noCamera: return "No camera found."
            case .cameraDenied: return "Blob isn’t allowed to use the camera."
            case .noFace: return "Couldn’t see a face. Face the camera in good light."
            case .notYou: return "That didn’t look like you."
            case .timedOut: return "Didn’t see a blink. Try again, or use Touch ID."
            case .notSetUp: return "Set up face unlock in Settings first."
            }
        }
    }

    private struct Saved: Codable {
        var prints: [Data]
        var threshold: Float
        var openEyes: Float
    }

    private struct Sample {
        var print: VNFeaturePrintObservation?
        var eyes: Float?
    }

    private static var file: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Blob", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("face.dat")
    }

    static var isEnrolled: Bool { FileManager.default.fileExists(atPath: file.path) }

    static func forget() { try? FileManager.default.removeItem(at: file) }

    // MARK: - Setup

    /// Looks at you for a few seconds and saves eight prints of your face.
    static func enroll(cameraID: String?, progress: @escaping @Sendable (Int) -> Void) async throws {
        try await ensureCameraAccess()
        var prints: [VNFeaturePrintObservation] = []
        var eyes: [Float] = []
        let deadline = Date().addingTimeInterval(20)
        var lastTaken = Date.distantPast
        for await sample in try frames(cameraID: cameraID) {
            if Date() > deadline { break }
            guard let print = sample.print, let e = sample.eyes else { continue }
            guard Date().timeIntervalSince(lastTaken) > 0.25 else { continue }
            prints.append(print)
            eyes.append(e)
            lastTaken = Date()
            progress(prints.count)
            if prints.count >= 8 { break }
        }
        guard prints.count >= 5 else { throw Failure.noFace }

        // How far apart your own prints are sets how strict matching is.
        var distances: [Float] = []
        for i in 0..<prints.count {
            for j in (i + 1)..<prints.count {
                var d: Float = 0
                try prints[i].computeDistance(&d, to: prints[j])
                distances.append(d)
            }
        }
        let spread = distances.sorted()[distances.count * 3 / 4]
        let saved = Saved(
            prints: try prints.map { try NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) },
            threshold: spread * 1.6,
            openEyes: eyes.sorted()[eyes.count / 2]
        )
        let data = try JSONEncoder().encode(saved)
        try data.write(to: file, options: .atomic)
    }

    // MARK: - Unlock

    /// Watches for up to 10 seconds for your face and a blink.
    static func verify(cameraID: String?) async throws {
        guard let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode(Saved.self, from: data) else {
            throw Failure.notSetUp
        }
        let known = saved.prints.compactMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: $0)
        }
        guard !known.isEmpty else { throw Failure.notSetUp }
        try await ensureCameraAccess()

        let closed = saved.openEyes * 0.55
        let open = saved.openEyes * 0.8
        enum Blink { case waitingOpen, open, shut, done }
        var blink = Blink.waitingOpen
        var matches = 0, matchesAfterBlink = 0, faces = 0, strangers = 0
        let deadline = Date().addingTimeInterval(10)

        for await sample in try frames(cameraID: cameraID) {
            if Date() > deadline { break }
            guard let print = sample.print, let eyes = sample.eyes else { continue }
            faces += 1
            let distance = known.compactMap { k -> Float? in
                var d: Float = 0
                return (try? print.computeDistance(&d, to: k)) != nil ? d : nil
            }.min() ?? .greatestFiniteMagnitude
            let isYou = distance <= saved.threshold
            if isYou { matches += 1 } else { strangers += 1 }

            switch blink {
            case .waitingOpen: if eyes > open { blink = .open }
            case .open: if eyes < closed { blink = .shut }
            case .shut: if eyes > open { blink = .done }
            case .done: if isYou { matchesAfterBlink += 1 }
            }
            if blink == .done, matches >= 3, matchesAfterBlink >= 1 { return }
        }
        if faces == 0 { throw Failure.noFace }
        if matches < 3 { throw strangers > 0 ? Failure.notYou : Failure.noFace }
        throw Failure.timedOut
    }

    // MARK: - Camera

    private static func ensureCameraAccess() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return
        case .notDetermined:
            if await AVCaptureDevice.requestAccess(for: .video) { return }
            throw Failure.cameraDenied
        default: throw Failure.cameraDenied
        }
    }

    /// Camera frames, analysed on a background queue. The camera turns off when the loop ends.
    private static func frames(cameraID: String?) throws -> AsyncStream<Sample> {
        let device = cameraID.flatMap { AVCaptureDevice(uniqueID: $0) } ?? AVCaptureDevice.default(for: .video)
        guard let device, let input = try? AVCaptureDeviceInput(device: device) else { throw Failure.noCamera }
        let session = AVCaptureSession()
        session.sessionPreset = .vga640x480
        guard session.canAddInput(input) else { throw Failure.noCamera }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        guard session.canAddOutput(output) else { throw Failure.noCamera }
        session.addOutput(output)

        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let reader = FrameReader { buffer in continuation.yield(analyse(buffer)) }
            let queue = DispatchQueue(label: "app.blob.face")
            output.setSampleBufferDelegate(reader, queue: queue)
            continuation.onTermination = { _ in
                queue.async {
                    output.setSampleBufferDelegate(nil, queue: nil)
                    session.stopRunning()
                    _ = reader
                }
            }
            queue.async { session.startRunning() }
        }
    }

    private final class FrameReader: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        private let handle: (CVPixelBuffer) -> Void
        private var count = 0
        init(_ handle: @escaping (CVPixelBuffer) -> Void) { self.handle = handle }
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            count += 1
            // About 10 checks a second is plenty.
            guard count % 3 == 0, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            handle(buffer)
        }
    }

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// One face, big enough, roughly facing the camera: its print and how open its eyes are.
    private static func analyse(_ buffer: CVPixelBuffer) -> Sample {
        let landmarks = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
        guard (try? handler.perform([landmarks])) != nil,
              let faces = landmarks.results, faces.count == 1, let face = faces.first,
              face.boundingBox.height > 0.18,
              abs(face.yaw?.doubleValue ?? 0) < 0.45
        else { return Sample() }

        let eyes = eyeOpenness(face)

        // Crop the face with a little margin and print it.
        let image = CIImage(cvPixelBuffer: buffer)
        let w = image.extent.width, h = image.extent.height
        var box = VNImageRectForNormalizedRect(face.boundingBox, Int(w), Int(h))
        box = box.insetBy(dx: -box.width * 0.12, dy: -box.height * 0.12).intersection(image.extent)
        guard let cg = context.createCGImage(image.cropped(to: box), from: box) else { return Sample(eyes: eyes) }
        let printRequest = VNGenerateImageFeaturePrintRequest()
        printRequest.imageCropAndScaleOption = .scaleFill
        guard (try? VNImageRequestHandler(cgImage: cg).perform([printRequest])) != nil,
              let print = printRequest.results?.first
        else { return Sample(eyes: eyes) }
        return Sample(print: print, eyes: eyes)
    }

    /// Eye height ÷ width, averaged over both eyes: about 0.3 open, under 0.15 shut.
    private static func eyeOpenness(_ face: VNFaceObservation) -> Float? {
        func ratio(_ region: VNFaceLandmarkRegion2D?) -> Float? {
            guard let points = region?.normalizedPoints, points.count >= 4 else { return nil }
            let xs = points.map(\.x), ys = points.map(\.y)
            let width = (xs.max() ?? 0) - (xs.min() ?? 0)
            guard width > 0 else { return nil }
            return Float(((ys.max() ?? 0) - (ys.min() ?? 0)) / width)
        }
        let values = [ratio(face.landmarks?.leftEye), ratio(face.landmarks?.rightEye)].compactMap { $0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Float(values.count)
    }
}
