import AppKit

enum NotchGeometry {
    /// The hardware notch size, or nil on screens without one.
    static func hardwareNotch(on screen: NSScreen) -> CGSize? {
        guard screen.safeAreaInsets.top > 0,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else { return nil }
        let width = screen.frame.width - left.width - right.width
        guard width > 0 else { return nil }
        return CGSize(width: width, height: screen.safeAreaInsets.top)
    }

    /// The size Blob uses when closed. Screens without a notch get a virtual one
    /// sized to the menu bar.
    static func closedSize(on screen: NSScreen) -> CGSize {
        if let notch = hardwareNotch(on: screen) { return notch }
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        return CGSize(width: 190, height: max(24, min(menuBar, 32)))
    }

    static func hasNotch(_ screen: NSScreen) -> Bool { hardwareNotch(on: screen) != nil }

    /// The screen with a notch, or the main screen.
    static var preferredScreen: NSScreen? {
        NSScreen.screens.first(where: hasNotch) ?? NSScreen.main ?? NSScreen.screens.first
    }
}
