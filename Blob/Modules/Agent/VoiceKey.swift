import AppKit

/// Push-to-talk on the Right Option key. Starts after a short hold, so quick taps and
/// Option shortcuts (⌥ + another key) never trigger it. Needs Accessibility access.
@MainActor
final class VoiceKey {
    var onBegin: () -> Void = {}
    var onEnd: () -> Void = {}
    var onCancel: () -> Void = {}

    private static let rightOption: UInt16 = 61
    private var monitors: [Any] = []
    private var holdTask: Task<Void, Never>?
    private var isDown = false
    private var isActive = false

    func start() {
        guard monitors.isEmpty else { return }
        let flags: (NSEvent) -> Void = { [weak self] e in MainActor.assumeIsolated { self?.flagsChanged(e) } }
        let keys: (NSEvent) -> Void = { [weak self] _ in MainActor.assumeIsolated { self?.otherKeyPressed() } }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: flags) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { flags($0); return $0 }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: keys) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { keys($0); return $0 }) { monitors.append(m) }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    private func flagsChanged(_ event: NSEvent) {
        guard event.keyCode == Self.rightOption else { return }
        let down = event.modifierFlags.contains(.option)
        if down, !isDown {
            isDown = true
            holdTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(220))
                guard let self, !Task.isCancelled, self.isDown else { return }
                self.isActive = true
                self.onBegin()
            }
        } else if !down, isDown {
            isDown = false
            holdTask?.cancel()
            if isActive {
                isActive = false
                onEnd()
            }
        }
    }

    /// ⌥ + a key is a shortcut or a special character, not a voice request.
    private func otherKeyPressed() {
        guard isDown else { return }
        isDown = false
        holdTask?.cancel()
        if isActive {
            isActive = false
            onCancel()
        }
    }
}
