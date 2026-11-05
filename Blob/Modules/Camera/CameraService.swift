import AVFoundation
import AppKit

/// Owns the capture session on its own queue.
final class CaptureBox {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "blob.camera")
    private var configured = false

    func start() {
        queue.async { [self] in
            if !configured {
                session.beginConfiguration()
                session.sessionPreset = .high
                if let device = AVCaptureDevice.default(for: .video),
                   let input = try? AVCaptureDeviceInput(device: device),
                   session.canAddInput(input) {
                    session.addInput(input)
                }
                session.commitConfiguration()
                configured = true
            }
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }
}

@MainActor
final class CameraService: ObservableObject {
    @Published private(set) var status = AVCaptureDevice.authorizationStatus(for: .video)
    let box = CaptureBox()
    private var visible = false

    var hasCamera: Bool { AVCaptureDevice.default(for: .video) != nil }

    /// The camera runs only while the Mirror tab is on screen.
    func setVisible(_ visible: Bool) {
        self.visible = visible
        status = AVCaptureDevice.authorizationStatus(for: .video)
        if visible, status == .authorized { box.start() } else { box.stop() }
    }

    func requestAccess() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            status = AVCaptureDevice.authorizationStatus(for: .video)
            if granted, visible { box.start() }
            if !granted, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
