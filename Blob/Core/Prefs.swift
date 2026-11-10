import Foundation

enum Prefs {
    static let openOnHover = "openOnHover"
    static let hoverDelay = "hoverDelay"
    static let allDisplays = "allDisplays"
    static let overFullScreen = "overFullScreen"
    static let haptics = "haptics"
    static let menuBarIcon = "menuBarIcon"
    static let replaceHUD = "replaceHUD"
    static let monochromeArtwork = "monochromeArtwork"
    static let claudeSounds = "claudeSounds"
    static let chargingNotice = "chargingNotice"
    static let timerSound = "timerSound"
    static let stayOpen = "stayOpen"
    static let requireAuth = "requireAuth"
    static let faceUnlock = "faceUnlock"
    static let phoneBridge = "phoneBridge"
    static let voiceKey = "voiceKey"
    static let appIcon = "appIcon"
    static let phoneTasks = "phoneTasks"
    static let selectedCamera = "selectedCamera"

    static func registerDefaults() {
        var defaults: [String: Any] = [
            openOnHover: true,
            hoverDelay: 0.3,
            allDisplays: false,
            overFullScreen: false,
            haptics: true,
            menuBarIcon: true,
            replaceHUD: true,
            monochromeArtwork: false,
            claudeSounds: true,
            chargingNotice: true,
            timerSound: true,
            stayOpen: false,
            requireAuth: false,
            faceUnlock: false,
            phoneBridge: false,
            voiceKey: true,
            phoneTasks: true,
        ]
        for module in ModuleID.allCases { defaults[module.prefKey] = true }
        UserDefaults.standard.register(defaults: defaults)
    }

    static func bool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
    static func double(_ key: String) -> Double { UserDefaults.standard.double(forKey: key) }
}
