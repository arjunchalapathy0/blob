import AppKit
import SwiftUI

/// Owns the panel for one screen and routes global mouse movement into the view model.
/// The panel ignores the mouse except over the notch itself, so the menu bar keeps working.
@MainActor
final class NotchWindowController {
    let panel: NotchPanel
    let vm: NotchViewModel
    private var monitors: [Any] = []
    private var dragChangeCount = NSPasteboard(name: .drag).changeCount

    static let canvas = NSSize(width: 820, height: 330)

    init(screen: NSScreen, services: Services) {
        vm = NotchViewModel(screen: screen, services: services)
        let frame = NSRect(x: screen.frame.midX - Self.canvas.width / 2,
                           y: screen.frame.maxY - Self.canvas.height,
                           width: Self.canvas.width, height: Self.canvas.height)
        panel = NotchPanel(contentRect: frame)

        let host = NSHostingView(rootView: NotchRootView(vm: vm).withServices(services))
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: Self.canvas)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.setFrame(frame, display: true)
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()

        vm.onLayoutChange = { [weak self] in self?.updatePassthrough() }
        installMonitors()
    }

    func teardown() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        vm.onLayoutChange = nil
        panel.orderOut(nil)
        panel.close()
    }

    func applyPreferences() { panel.applyFullScreenBehavior() }

    private func installMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event, local: false) }
        }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask.union(.keyDown), handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event, local: true) }
            return event
        }) { monitors.append(local) }
    }

    private func handle(_ event: NSEvent, local: Bool) {
        let point = NSEvent.mouseLocation
        switch event.type {
        case .keyDown:
            if event.keyCode == 53 { vm.close() } // esc
        case .leftMouseDown:
            dragChangeCount = NSPasteboard(name: .drag).changeCount
            if vm.phase == .open, !local, !vm.isPinned, !vm.isWelcoming, !vm.hitRect().contains(point) { vm.close() }
        case .leftMouseDragged:
            let pb = NSPasteboard(name: .drag)
            if pb.changeCount != dragChangeCount, ModuleID.shelf.isEnabled,
               pb.types?.contains(.fileURL) == true, vm.dropZone().contains(point) {
                vm.open(tab: .shelf)
            }
            vm.mouseMoved(to: point)
        default:
            vm.mouseMoved(to: point)
        }
        updatePassthrough()
    }

    private func updatePassthrough() {
        // Only take the mouse over the notch itself, so a pinned notch never blocks
        // clicks on whatever is underneath the rest of the transparent window.
        let accept = vm.hitRect().contains(NSEvent.mouseLocation) || vm.isDropTargeted
        if panel.ignoresMouseEvents == accept { panel.ignoresMouseEvents = !accept }

        // Take the keyboard for the Ask field; hand it back to the frontmost app afterwards.
        if vm.wantsKeyboard, !panel.isKeyWindow {
            panel.makeKey()
        } else if !vm.wantsKeyboard, panel.isKeyWindow {
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
    }
}
