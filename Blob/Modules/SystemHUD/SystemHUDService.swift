import AppKit
import Combine
import ApplicationServices

/// Replaces the macOS volume and brightness HUD with the notch.
@MainActor
final class SystemHUDService: ObservableObject {
    @Published private(set) var isTrusted = AXIsProcessTrusted()
    @Published private(set) var isActive = false

    private let notices: NoticeCenter
    private var tap: MediaKeyTap?
    private var bag = Set<AnyCancellable>()

    init(notices: NoticeCenter) { self.notices = notices }

    func start() {
        // Accessibility can be granted at any time, so keep checking.
        Timer.publish(every: 2, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &bag)
        refresh()
    }

    func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }
        let wanted = trusted && Prefs.bool(Prefs.replaceHUD)
        if wanted, tap == nil {
            let t = MediaKeyTap { [weak self] key, down, flags in
                MainActor.assumeIsolated { self?.handle(key, down: down, flags: flags) ?? false }
            }
            if t.start() { tap = t }
        } else if !wanted, let t = tap {
            t.stop()
            tap = nil
        }
        let active = tap?.isRunning ?? false
        if active != isActive { isActive = active }
    }

    private func handle(_ key: MediaKeyTap.Key, down: Bool, flags: NSEvent.ModifierFlags) -> Bool {
        let fine = flags.contains(.shift) && flags.contains(.option)
        let step: Float = fine ? 1 / 64 : 1 / 16

        switch key {
        case .volumeUp, .volumeDown:
            guard SystemAudio.canSetVolume else { return false }
            if down {
                let delta = key == .volumeUp ? step : -step
                let value = max(0, min(1, SystemAudio.volume + delta))
                SystemAudio.volume = value
                if key == .volumeUp, SystemAudio.isMuted { SystemAudio.isMuted = false }
                notices.post(.volume(value, muted: SystemAudio.isMuted))
                playFeedback(flags)
            }
            return true

        case .mute:
            if down {
                SystemAudio.isMuted.toggle()
                notices.post(.volume(SystemAudio.volume, muted: SystemAudio.isMuted))
            }
            return true

        case .brightnessUp, .brightnessDown:
            guard DisplayBrightness.isAvailable, let current = DisplayBrightness.get() else { return false }
            if down {
                let delta = key == .brightnessUp ? step : -step
                let value = max(0, min(1, current + delta))
                DisplayBrightness.set(value)
                notices.post(.brightness(value))
            }
            return true
        }
    }

    /// Mirrors the macOS "Play feedback when volume is changed" setting (shift inverts it).
    private func playFeedback(_ flags: NSEvent.ModifierFlags) {
        let global = UserDefaults(suiteName: "NSGlobalDomain")
        let enabled = (global?.object(forKey: "com.apple.sound.beep.feedback") as? Int ?? 0) == 1
        guard enabled != flags.contains(.shift) else { return }
        NSSound(named: "Pop")?.play()
    }
}
