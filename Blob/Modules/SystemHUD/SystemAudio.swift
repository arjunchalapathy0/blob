import CoreAudio
import AudioToolbox

/// Default output device volume and mute.
enum SystemAudio {
    static var outputDevice: AudioObjectID {
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return id
    }

    private static var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)

    private static var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)

    static var canSetVolume: Bool {
        var settable: DarwinBoolean = false
        let device = outputDevice
        guard AudioObjectHasProperty(device, &volumeAddress) else { return false }
        return AudioObjectIsPropertySettable(device, &volumeAddress, &settable) == noErr && settable.boolValue
    }

    static var volume: Float {
        get {
            var value = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            AudioHardwareServiceGetPropertyData(outputDevice, &volumeAddress, 0, nil, &size, &value)
            return value
        }
        set {
            var value = Float32(max(0, min(1, newValue)))
            AudioHardwareServiceSetPropertyData(outputDevice, &volumeAddress, 0, nil,
                                                UInt32(MemoryLayout<Float32>.size), &value)
        }
    }

    static var isMuted: Bool {
        get {
            var value = UInt32(0)
            var size = UInt32(MemoryLayout<UInt32>.size)
            let device = outputDevice
            guard AudioObjectHasProperty(device, &muteAddress) else { return false }
            AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &size, &value)
            return value != 0
        }
        set {
            var value = UInt32(newValue ? 1 : 0)
            let device = outputDevice
            guard AudioObjectHasProperty(device, &muteAddress) else { return }
            AudioObjectSetPropertyData(device, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        }
    }
}
