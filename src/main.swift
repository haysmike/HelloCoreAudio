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
    if status != noErr {
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
    return withUnsafeTemporaryAllocation(of: type, capacity: count) {
        bufferPointer in

        if let pointer = bufferPointer.baseAddress {
            let status = AudioObjectGetPropertyData(
                id, &address, 0, nil, &size, pointer)
            if status != noErr {
                print("getAudioObjectPropertyData error: \(status)")
                return []
            }
            return Array(bufferPointer)
        } else {
            return []
        }
    }
}

func getAudioObjectPropertyDataItem<T>(
    id: AudioObjectID,
    address: inout AudioObjectPropertyAddress,
    type: T.Type
) -> T? {
    let array = getAudioObjectPropertyDataArray(
        id: id, address: &address, type: type)
    assert(array.count < 2)
    return array.first
}

func getAudioObjectPropertyDataString(
    id: AudioObjectID,
    address: inout AudioObjectPropertyAddress,
    fallback: String
) -> String {
    let array = getAudioObjectPropertyDataArray(
        id: id, address: &address, type: CFString.self)
    assert(array.count < 2)
    return if let string = array.first {
        string as String
    } else {
        fallback
    }
}

func buildPropertyAddress(
    _ selector: AudioObjectPropertySelector,
    _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
) -> AudioObjectPropertyAddress {
    return AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain)
}

func checkFlags(flags: AudioFormatFlags, expected: AudioFormatFlags) -> Bool {
    return flags & expected == expected
}

struct AudioInputDevice {
    var id: UInt32
    var isDefault: Bool
    var manufacturer: String
    var name: String
    var inputStreamFormat: AudioStreamBasicDescription
    //    var inputStreamConfiguration: AudioBufferList
}

var defaultDeviceIdAddress = buildPropertyAddress(
    kAudioHardwarePropertyDefaultInputDevice)
let defaultDeviceId = getAudioObjectPropertyDataItem(
    id: AudioObjectID(kAudioObjectSystemObject),
    address: &defaultDeviceIdAddress,
    type: AudioDeviceID.self)

var deviceIdsAddress = buildPropertyAddress(kAudioHardwarePropertyDevices)
let deviceIds = getAudioObjectPropertyDataArray(
    id: AudioObjectID(kAudioObjectSystemObject),
    address: &deviceIdsAddress,
    type: UInt32.self
)

let inputDevices: [AudioInputDevice] = deviceIds.compactMap { deviceId in
    var inputConfigurationAddress = buildPropertyAddress(
        kAudioDevicePropertyStreamConfiguration, kAudioDevicePropertyScopeInput)
    let inputConfiguration = getAudioObjectPropertyDataItem(
        id: deviceId,
        address: &inputConfigurationAddress,
        type: AudioBufferList.self
    )
    // Trying to get the input stream format for devices that don't have inputs logs errors (but doesn't throw)
    if inputConfiguration == nil {
        return nil
    }

    var streamFormatAddress = buildPropertyAddress(
        kAudioDevicePropertyStreamFormat, kAudioDevicePropertyScopeInput)
    let streamFormat = getAudioObjectPropertyDataItem(
        id: deviceId,
        address: &streamFormatAddress,
        type: AudioStreamBasicDescription.self
    )

    var manufacturerAddress = buildPropertyAddress(
        kAudioDevicePropertyDeviceManufacturerCFString)
    let manufacturer = getAudioObjectPropertyDataString(
        id: deviceId, address: &manufacturerAddress, fallback: "???")

    var nameAddress = buildPropertyAddress(
        kAudioDevicePropertyDeviceNameCFString)
    let name = getAudioObjectPropertyDataString(
        id: deviceId,
        address: &nameAddress,
        fallback: "???"
    )

    //    let defaultMarker = deviceId == defaultDeviceId ? " *" : ""
    //    print("\(manufacturer) - \(name)\(defaultMarker) (\(deviceId))")

    //    if let inputConfiguration = inputConfiguration {
    //        print("\(inputConfiguration.mBuffers.mNumberChannels) inputs")
    //    }

    //    var outputConfigurationAddress = buildAddress(
    //        kAudioDevicePropertyStreamConfiguration, kAudioDevicePropertyScopeOutput
    //    )
    //    let outputConfiguration = getAudioObjectPropertyDataItem(
    //        id: deviceId,
    //        address: &outputConfigurationAddress,
    //        type: AudioBufferList.self
    //    )
    //    if let outputConfiguration = outputConfiguration {
    //        print("\(outputConfiguration.mBuffers.mNumberChannels) outputs")
    //    }

    //    if let streamFormat = streamFormat {
    //        //        print("stream format: \(streamFormat)")
    //        let is32BitFloat = checkFlags(
    //            flags: streamFormat.mFormatFlags,
    //            expected: kAudioFormatFlagsNativeFloatPacked
    //        )
    //        //        print("32-bit float? \(is32BitFloat)")
    //    }

    return AudioInputDevice(
        id: deviceId,
        isDefault: deviceId == defaultDeviceId,
        manufacturer: manufacturer,
        name: name,
        inputStreamFormat: streamFormat!
    )
}

for device in inputDevices {
    print(device)
}

var procId: AudioDeviceIOProcID?

//AudioDeviceCreateIOProcIDWithBlock(&procId, defaultDeviceId!, nil) {
//    inNow, inInputData, inInputTime, outOutputData, inOutputTime in
//
//    print("hello \(String(describing: inInputData.pointee.mBuffers.mData))")
//}
