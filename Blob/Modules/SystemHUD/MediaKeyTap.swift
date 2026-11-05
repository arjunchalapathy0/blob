import AppKit

/// Intercepts the media keys (volume, brightness) with a CGEventTap so Blob can handle
/// them and swallow the event, which replaces the system OSD. Needs Accessibility access.
final class MediaKeyTap {
    enum Key: Int {
        case volumeUp = 0, volumeDown = 1, brightnessUp = 2, brightnessDown = 3, mute = 7
    }

    /// Return true to swallow the event.
    typealias Handler = (_ key: Key, _ isDown: Bool, _ flags: NSEvent.ModifierFlags) -> Bool

    fileprivate var port: CFMachPort?
    private var source: CFRunLoopSource?
    fileprivate let handler: Handler

    init(handler: @escaping Handler) { self.handler = handler }

    deinit { stop() }

    var isRunning: Bool { port.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    @discardableResult
    func start() -> Bool {
        guard port == nil else { return true }
        let mask = CGEventMask(1 << 14) // NX_SYSDEFINED
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                           place: .headInsertEventTap,
                                           options: .defaultTap,
                                           eventsOfInterest: mask,
                                           callback: mediaKeyCallback,
                                           userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        self.port = port
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        source = src
        return true
    }

    func stop() {
        if let port { CGEvent.tapEnable(tap: port, enable: false); CFMachPortInvalidate(port) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        port = nil
        source = nil
    }
}

private func mediaKeyCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                              refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<MediaKeyTap>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let port = tap.port { CGEvent.tapEnable(tap: port, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    guard type.rawValue == 14,
          let ns = NSEvent(cgEvent: event),
          ns.subtype.rawValue == 8 else { return Unmanaged.passUnretained(event) }

    let code = (ns.data1 & 0xFFFF_0000) >> 16
    let flags = ns.data1 & 0x0000_FFFF
    let isDown = ((flags & 0xFF00) >> 8) == 0x0A
    guard let key = MediaKeyTap.Key(rawValue: code) else { return Unmanaged.passUnretained(event) }

    return tap.handler(key, isDown, ns.modifierFlags) ? nil : Unmanaged.passUnretained(event)
}
