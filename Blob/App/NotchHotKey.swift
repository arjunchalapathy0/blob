import AppKit
import Carbon

/// System-wide ⌃⌥B. Uses a Carbon hot key so it works without Accessibility access.
final class NotchHotKey {
    var onPressed: () -> Void = {}

    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func start() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            Unmanaged<NotchHotKey>.fromOpaque(userData).takeUnretainedValue().fire()
            return noErr
        }, 1, &spec, pointer, &handler)
        guard installed == noErr else { return }
        var id = EventHotKeyID(signature: OSType(0x424C4F42), id: 1) // 'BLOB'
        RegisterEventHotKey(UInt32(kVK_ANSI_B), UInt32(controlKey | optionKey), id,
                            GetApplicationEventTarget(), 0, &hotKey)
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }

    private func fire() {
        DispatchQueue.main.async { [weak self] in self?.onPressed() }
    }

    deinit { stop() }
}
