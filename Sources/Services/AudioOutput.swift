import CoreAudio
import Foundation

/// Makes a just-connected Bluetooth device the system's default output via CoreAudio.
enum AudioOutput {
    /// Retries for ~3 seconds because the audio device appears shortly after the link comes up.
    static func makeDefault(name: String, address: String) {
        let key = address.filter(\.isHexDigit).lowercased()
        for _ in 0..<10 {
            if let id = findDevice(name: name, addressKey: key) {
                setDefault(id)
                return
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    private static func findDevice(name: String, addressKey: String) -> AudioDeviceID? {
        var address = propertyAddress(kAudioHardwarePropertyDevices)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return nil }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return nil }
        return ids.first { id in
            guard hasOutput(id) else { return false }
            let uid = string(id, kAudioDevicePropertyDeviceUID).filter(\.isHexDigit).lowercased()
            return string(id, kAudioObjectPropertyName) == name || (!addressKey.isEmpty && uid.contains(addressKey))
        }
    }

    private static func hasOutput(_ id: AudioDeviceID) -> Bool {
        var address = propertyAddress(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func string(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String {
        var address = propertyAddress(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr,
              let value else { return "" }
        return value.takeRetainedValue() as String
    }

    private static func setDefault(_ id: AudioDeviceID) {
        var address = propertyAddress(kAudioHardwarePropertyDefaultOutputDevice)
        var device = id
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
                                   UInt32(MemoryLayout<AudioDeviceID>.size), &device)
    }

    private static func propertyAddress(_ selector: AudioObjectPropertySelector,
                                        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal)
        -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
}
