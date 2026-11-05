import AVFoundation
import AppKit

/// Owns the capture session on its own queue.
final class CaptureBox {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "blob.camera")
    private var currentID: String?

    /// Starts the session with the given camera (nil = system default).
    func start(cameraID: String?) {
        queue.async { [self] in
            let device = cameraID.flatMap { AVCaptureDevice(uniqueID: $0) } ?? AVCaptureDevice.default(for: .video)
            if session.inputs.isEmpty || device?.uniqueID != currentID {
                session.beginConfiguration()
                session.inputs.forEach(session.removeInput)
                session.sessionPreset = .high
                if let device, let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
                    session.addInput(input)
                    currentID = device.uniqueID
                }
                session.commitConfiguration()
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
    struct Camera: Identifiable, Hashable { let id: String; let name: String }

    @Published private(set) var status = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var cameras: [Camera] = []
    @Published private(set) var selectedCameraID: String?
    @Published private(set) var microphones: [AudioDevices.Device] = []
    @Published private(set) var selectedMicID: AudioDeviceID = 0

    let box = CaptureBox()
    private var visible = false
    private var observing = false

    var hasCamera: Bool { !cameras.isEmpty }

    init() {
        selectedCameraID = UserDefaults.standard.string(forKey: Prefs.selectedCamera)
        refreshDevices()
    }

    func refreshDevices() {
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
                                                         mediaType: .video, position: .unspecified)
        cameras = discovery.devices.map { Camera(id: $0.uniqueID, name: $0.localizedName) }
        if let id = selectedCameraID, !cameras.contains(where: { $0.id == id }) { selectedCameraID = nil }
        microphones = AudioDevices.inputs()
        selectedMicID = AudioDevices.defaultInput

        guard !observing else { return }
        observing = true
        AudioDevices.observe { [weak self] in
            MainActor.assumeIsolated { self?.refreshDevices() }
        }
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshDevices() }
            }
        }
    }

    var currentCameraName: String {
        cameras.first { $0.id == selectedCameraID }?.name ?? cameras.first?.name ?? "Camera"
    }

    var currentMicName: String {
        microphones.first { $0.id == selectedMicID }?.name ?? "Microphone"
    }

    func selectCamera(_ camera: Camera) {
        selectedCameraID = camera.id
        UserDefaults.standard.set(camera.id, forKey: Prefs.selectedCamera)
        if visible, status == .authorized { box.start(cameraID: camera.id) }
    }

    /// Sets the Mac's default input, so every app uses this microphone.
    func selectMicrophone(_ mic: AudioDevices.Device) {
        AudioDevices.defaultInput = mic.id
        selectedMicID = AudioDevices.defaultInput
    }

    /// The camera runs only while the Mirror tab is on screen.
    func setVisible(_ visible: Bool) {
        self.visible = visible
        status = AVCaptureDevice.authorizationStatus(for: .video)
        if visible { refreshDevices() }
        if visible, status == .authorized { box.start(cameraID: selectedCameraID) } else { box.stop() }
    }

    func requestAccess() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            status = AVCaptureDevice.authorizationStatus(for: .video)
            if granted, visible { box.start(cameraID: selectedCameraID) }
            if !granted, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
