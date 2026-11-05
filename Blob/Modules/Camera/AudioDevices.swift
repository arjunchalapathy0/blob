import CoreAudio
import Foundation

/// Audio input devices and the system default microphone.
enum AudioDevices {
    struct Device: Identifiable, Hashable {
        let id: AudioDeviceID
        let name: String
    }

    private static var system: AudioObjectID { AudioObjectID(kAudioObjectSystemObject) }

    static func inputs() -> [Device] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.filter(hasInput).map { Device(id: $0, name: name(of: $0)) }
    }

    static var defaultInput: AudioDeviceID {
        get {
            var id = AudioDeviceID(0)
            var size = UInt32(MemoryLayout<AudioDeviceID>.size)
            var address = defaultInputAddress
            AudioObjectGetPropertyData(system, &address, 0, nil, &size, &id)
            return id
        }
        set {
            var id = newValue
            var address = defaultInputAddress
            AudioObjectSetPropertyData(system, &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id)
        }
    }

    /// Calls `handler` on the main queue when devices are added/removed or the default changes.
    static func observe(_ handler: @escaping () -> Void) {
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultInputDevice] {
            var address = AudioObjectPropertyAddress(mSelector: selector,
                                                     mScope: kAudioObjectPropertyScopeGlobal,
                                                     mElement: kAudioObjectPropertyElementMain)
            AudioObjectAddPropertyListenerBlock(system, &address, DispatchQueue.main) { _, _ in handler() }
        }
    }

    private static var defaultInputAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                   mScope: kAudioObjectPropertyScopeGlobal,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    private static func hasInput(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams,
                                                 mScope: kAudioDevicePropertyScopeInput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func name(of id: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name) == noErr, let name else { return "Microphone" }
        return name.takeRetainedValue() as String
    }
}
