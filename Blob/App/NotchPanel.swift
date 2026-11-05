import AppKit

/// Borderless, transparent, non-activating panel that sits above the menu bar.
final class NotchPanel: NSPanel {
    convenience init(contentRect: NSRect) {
        self.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        animationBehavior = .none
        applyFullScreenBehavior()
    }

    func applyFullScreenBehavior() {
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        if UserDefaults.standard.bool(forKey: Prefs.overFullScreen) { behavior.insert(.fullScreenAuxiliary) }
        collectionBehavior = behavior
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
