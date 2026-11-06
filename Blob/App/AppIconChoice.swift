import AppKit

/// Blob's icon: dark (default) or light. Blob has no Dock icon, so the choice is applied to the
/// app bundle, where Finder, Launchpad, Spotlight and System Settings show it.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case blob, light

    var id: String { rawValue }
    var title: String { self == .blob ? "Blob" : "Light" }
    var previewImage: String { self == .blob ? "IconPreviewBlob" : "IconPreviewLight" }

    static var current: AppIconChoice {
        AppIconChoice(rawValue: UserDefaults.standard.string(forKey: Prefs.appIcon) ?? "") ?? .blob
    }

    @MainActor
    static func select(_ choice: AppIconChoice) {
        UserDefaults.standard.set(choice.rawValue, forKey: Prefs.appIcon)
        apply()
    }

    /// Re-applies the light icon after an update replaced the app (updates install a fresh copy).
    @MainActor
    static func applyAtLaunch() {
        if current == .light { apply() }
    }

    @MainActor
    private static func apply() {
        let image = current == .light ? NSImage(named: "IconLight") : nil
        NSWorkspace.shared.setIcon(image, forFile: Bundle.main.bundlePath, options: [])
        NSApp.applicationIconImage = image
    }
}
