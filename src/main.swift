import CoreAudio
import Foundation

// https://gist.github.com/SteveTrewick/c0668ee438eb784cbc5fb4674f0c2cd1
// https://github.com/AudioKit/AudioKit/blob/main/Sources/AudioKit/Internals/Hardware/DeviceUtils.swift

func getAudioObjectPropertyDataSize(
    id: AudioObjectID,
    address: inout AudioObjectPropertyAddress
) -> UInt32 {
    var size: UInt32 = 0
    let status = AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size)
    if status != 0 {
        print("AudioObjectGetPropertyDataSize error: \(status)")
    }
    return size
}

func getAudioObjectPropertyDataArray<T>(
    id: AudioObjectID,
    address: inout AudioObjectPropertyAddress,
    type: T.Type
) -> [T] {
    var size = getAudioObjectPropertyDataSize(id: id, address: &address)
    let count = Int(size) / MemoryLayout<T>.size

    // TODO Apparently it's safer to use `.withUnsafeMutableBufferPointer {}`,
    // but that doesn't work well with generics (since it's hard to allocate arrays of generics)
    let buffer = UnsafeMutablePointer<T>.allocate(capacity: count)
    let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, buffer)
    if status != 0 {
        print("getAudioObjectPropertyData error: \(status)")
    }
    let array = Array(UnsafeBufferPointer(start: buffer, count: count))
    buffer.deallocate()
    return array
}

func getAudioObjectPropertyDataItem<T>(
    id: AudioObjectID,
    address: inout AudioObjectPropertyAddress,
    type: T.Type
) -> [T] {
    var size = getAudioObjectPropertyDataSize(id: id, address: &address)
    if size != 1 {
        print("error: size was \(size)")
        // TODO throw?
    }
    let count = Int(size) / MemoryLayout<T>.size
    let buffer = UnsafeMutablePointer<T>.allocate(capacity: count)
    let status = AudioObjectGetPropertyData(
        id,
        &address,
        0,
        nil,
        &size,
        buffer
    )
    if status != 0 {
        print("getAudioObjectPropertyData error: \(status)")
    }
    return Array(UnsafeBufferPointer(start: buffer, count: count))
}

func buildAddressFromSelector(
    selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
) -> AudioObjectPropertyAddress {
    return AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )
}

var defaultDeviceIdAddress = buildAddressFromSelector(
    selector: kAudioHardwarePropertyDefaultInputDevice)
let defaultDeviceId = getAudioObjectPropertyDataArray(
    id: AudioObjectID(kAudioObjectSystemObject),
    address: &defaultDeviceIdAddress,
    type: AudioDeviceID.self)

print("Got device ID \(defaultDeviceId)")

var deviceIdsAddress = buildAddressFromSelector(
    selector: kAudioHardwarePropertyDevices)
let deviceIds = getAudioObjectPropertyDataArray(
    id: AudioObjectID(kAudioObjectSystemObject),
    address: &deviceIdsAddress,
    type: UInt32.self
)

for deviceId in deviceIds {
    var manufacturerAddress = buildAddressFromSelector(
        selector: kAudioDevicePropertyDeviceManufacturerCFString)
    let manufacturer = getAudioObjectPropertyDataArray(
        id: deviceId,
        address: &manufacturerAddress,
        type: CFString.self
    )

    var nameAddress = buildAddressFromSelector(
        selector: kAudioDevicePropertyDeviceNameCFString)
    let name = getAudioObjectPropertyDataArray(
        id: deviceId,
        address: &nameAddress,
        type: CFString.self
    )

    let defaultMarker = deviceId == defaultDeviceId.first ? " *" : ""
    print("\(manufacturer) - \(name)\(defaultMarker)")

    var inputConfigurationAddress = buildAddressFromSelector(
        selector: kAudioDevicePropertyStreamConfiguration,
        scope: kAudioDevicePropertyScopeInput
    )
    let inputConfiguration = getAudioObjectPropertyDataArray(
        id: deviceId,
        address: &inputConfigurationAddress,
        type: AudioBufferList.self
    )
    for configuration in inputConfiguration {
        print("\(configuration.mBuffers.mNumberChannels) inputs")
    }

    var outputConfigurationAddress = buildAddressFromSelector(
        selector: kAudioDevicePropertyStreamConfiguration,
        scope: kAudioDevicePropertyScopeOutput
    )
    let outputConfiguration = getAudioObjectPropertyDataArray(
        id: deviceId,
        address: &outputConfigurationAddress,
        type: AudioBufferList.self
    )
    for configuration in outputConfiguration {
        print("\(configuration.mBuffers.mNumberChannels) outputs")
    }
}
