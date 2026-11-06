import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let services = Services.shared
    private var controllers: [NotchWindowController] = []
    private var bag = Set<AnyCancellable>()
    private var lastLayoutPrefs: [Bool] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        services.start()
        rebuild()
        announceUpdateIfNeeded()

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &bag)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.preferencesChanged() }
            .store(in: &bag)

        lastLayoutPrefs = layoutPrefs
    }

    func applicationWillTerminate(_ notification: Notification) {
        services.tools.releaseCaffeinate()
        services.nowPlaying.stop()
    }

    /// Shows "Updated to x.y.z" in the notch the first time a new version launches.
    private func announceUpdateIfNeeded() {
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let key = "lastLaunchedVersion"
        let previous = UserDefaults.standard.string(forKey: key)
        UserDefaults.standard.set(current, forKey: key)
        guard let previous, previous != current else { return }
        Task {
            try? await Task.sleep(for: .seconds(1))
            services.notices.message("sparkles", "Updated to \(current)", duration: 4)
        }
    }

    private var layoutPrefs: [Bool] { [Prefs.bool(Prefs.allDisplays)] }

    private func preferencesChanged() {
        controllers.forEach { $0.applyPreferences() }
        if layoutPrefs != lastLayoutPrefs {
            lastLayoutPrefs = layoutPrefs
            rebuild()
        }
    }

    private func rebuild() {
        controllers.forEach { $0.teardown() }
        let screens: [NSScreen]
        if Prefs.bool(Prefs.allDisplays) {
            screens = NSScreen.screens
        } else {
            screens = NotchGeometry.preferredScreen.map { [$0] } ?? []
        }
        controllers = screens.map { NotchWindowController(screen: $0, services: services) }
    }
}
