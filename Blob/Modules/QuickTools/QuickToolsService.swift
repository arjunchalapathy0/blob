import AppKit
import IOKit.pwr_mgt

@MainActor
final class QuickToolsService: ObservableObject {
    @Published private(set) var isCaffeinated = false
    private var assertion: IOPMAssertionID = 0
    private let notices: NoticeCenter

    init(notices: NoticeCenter) { self.notices = notices }

    // Keep awake
    func toggleCaffeinate() {
        if isCaffeinated {
            releaseCaffeinate()
            notices.message("moon.zzz", "Sleep allowed")
        } else {
            let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                                     IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                     "Blob is keeping your Mac awake" as CFString,
                                                     &assertion)
            isCaffeinated = result == kIOReturnSuccess
            if isCaffeinated { notices.message("cup.and.saucer.fill", "Staying awake") }
        }
    }

    func releaseCaffeinate() {
        guard isCaffeinated else { return }
        IOPMAssertionRelease(assertion)
        isCaffeinated = false
    }

    // Color picker
    func pickColor() {
        NSColorSampler().show { [weak self] color in
            guard let self, let c = color?.usingColorSpace(.sRGB) else { return }
            let hex = String(format: "#%02X%02X%02X",
                             Int((c.redComponent * 255).rounded()),
                             Int((c.greenComponent * 255).rounded()),
                             Int((c.blueComponent * 255).rounded()))
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hex, forType: .string)
            self.notices.message("eyedropper", hex, duration: 2.5)
        }
    }

    // Screenshot to clipboard
    func screenshot() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-i", "-c"]
        let before = NSPasteboard.general.changeCount
        p.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                if NSPasteboard.general.changeCount != before {
                    self?.notices.message("camera.viewfinder", "Screenshot copied")
                }
            }
        }
        try? p.run()
    }

    // Appearance
    func toggleDarkMode() {
        let source = "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if error != nil {
            notices.message("exclamationmark.triangle", "Allow Automation")
        }
    }

    // Display sleep
    func sleepDisplay() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        p.arguments = ["displaysleepnow"]
        try? p.run()
    }

    // Activity Monitor
    func openActivityMonitor() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
            NSWorkspace.shared.open(url)
        }
    }
}
