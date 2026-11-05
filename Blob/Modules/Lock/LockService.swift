import AppKit
import LocalAuthentication

/// Optional Touch ID lock for private tabs (Clipboard, Shelf, Ask). Falls back to the Mac
/// password or Apple Watch. Locks again 30 s after the notch closes, and when the screen locks.
@MainActor
final class LockService: ObservableObject {
    @Published private(set) var isUnlocked = false
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
        isUnlocked = false
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
                       detail: "Unlock with \(lock.biometryName).",
                       mood: .sleepy, actionTitle: "Unlock") { lock.unlock() }
        } else {
            content
        }
    }
}
