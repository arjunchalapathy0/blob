import AppKit
import LocalAuthentication
import SwiftUI

/// Optional Touch ID lock for private tabs (Clipboard, Shelf, Ask). Falls back to the Mac
/// password or Apple Watch, and can also unlock with your face through the camera (FaceUnlock).
/// Locks again 30 s after the notch closes, and when the screen locks.
@MainActor
final class LockService: ObservableObject {
    @Published private(set) var isUnlocked = false
    /// What face unlock is doing right now, for the locked screen and Settings.
    @Published private(set) var faceStatus: String?
    @Published private(set) var isScanningFace = false
    @Published private(set) var faceEnrolled = FaceUnlock.isEnrolled
    private var faceTask: Task<Void, Never>?
    private var relockTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    static let protected: Set<ModuleID> = [.clipboard, .shelf, .ask]

    var isEnabled: Bool { Prefs.bool(Prefs.requireAuth) }

    var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType == .touchID ? "Touch ID" : "your password"
    }

    func needsUnlock(_ module: ModuleID) -> Bool {
        isEnabled && !isUnlocked && Self.protected.contains(module)
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lock() }
        })
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lock() }
        })
    }

    func unlock() {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No password or biometrics set up on this Mac: nothing to check against.
            isUnlocked = true
            return
        }
        Task {
            let ok = (try? await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                        localizedReason: "unlock your private Blob tabs")) ?? false
            if ok { isUnlocked = true }
        }
    }

    func lock() {
        relockTask?.cancel()
        faceTask?.cancel()
        isUnlocked = false
    }

    // MARK: - Face

    var faceEnabled: Bool { Prefs.bool(Prefs.faceUnlock) && faceEnrolled }

    private var cameraID: String? { UserDefaults.standard.string(forKey: Prefs.selectedCamera) }

    /// Look at the camera and blink. Used automatically when a locked tab appears.
    func unlockWithFace() {
        guard faceEnabled, !isUnlocked, !isScanningFace else { return }
        isScanningFace = true
        faceStatus = "Look at the camera and blink"
        let camera = cameraID
        faceTask = Task {
            do {
                try await FaceUnlock.verify(cameraID: camera)
                guard !Task.isCancelled else { return }
                isUnlocked = true
                faceStatus = nil
            } catch {
                if !Task.isCancelled { faceStatus = error.localizedDescription }
            }
            isScanningFace = false
        }
    }

    /// Settings: look at the camera for a few seconds to save your face.
    func setUpFace() {
        guard !isScanningFace else { return }
        isScanningFace = true
        faceStatus = "Look at the camera…"
        let camera = cameraID
        faceTask = Task {
            do {
                try await FaceUnlock.enroll(cameraID: camera) { count in
                    Task { @MainActor in self.faceStatus = "Hold still… \(count) of 8" }
                }
                faceEnrolled = true
                UserDefaults.standard.set(true, forKey: Prefs.faceUnlock)
                faceStatus = "Your face is set up. Unlock by looking and blinking."
            } catch {
                faceStatus = error.localizedDescription
            }
            isScanningFace = false
        }
    }

    func forgetFace() {
        faceTask?.cancel()
        FaceUnlock.forget()
        faceEnrolled = false
        isScanningFace = false
        UserDefaults.standard.set(false, forKey: Prefs.faceUnlock)
        faceStatus = nil
    }

    func notchOpened() { relockTask?.cancel() }

    func notchClosed() {
        guard isUnlocked else { return }
        relockTask?.cancel()
        relockTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            self?.isUnlocked = false
        }
    }
}

/// Shows its content only when the module isn't locked.
struct LockGate<Content: View>: View {
    let module: ModuleID
    @ViewBuilder var content: Content
    @EnvironmentObject private var lock: LockService

    var body: some View {
        if lock.needsUnlock(module) {
            EmptyState(text: "\(module.title) is locked",
                       detail: lock.faceEnabled
                           ? (lock.faceStatus ?? "Look at the camera and blink, or use \(lock.biometryName).")
                           : "Unlock with \(lock.biometryName).",
                       mood: lock.isScanningFace ? .curious : .sleepy,
                       actionTitle: lock.faceEnabled && !lock.isScanningFace ? "Try my face again" : "Unlock") {
                if lock.faceEnabled && !lock.isScanningFace { lock.unlockWithFace() } else { lock.unlock() }
            }
            .task { lock.unlockWithFace() }
            .overlay(alignment: .bottomTrailing) {
                if lock.faceEnabled {
                    PillButton(title: lock.biometryName == "Touch ID" ? "Touch ID" : "Password", prominent: false) { lock.unlock() }
                }
            }
        } else {
            content
        }
    }
}
