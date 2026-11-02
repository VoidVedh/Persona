import AudioToolbox
import CoreAudio
import Foundation
import PersonaCore

public struct VolumeState: Equatable {
    public var percent: Int
    public var isMuted: Bool

    public init(percent: Int, isMuted: Bool) {
        self.percent = percent
        self.isMuted = isMuted
    }
}

public final class VolumeSampler {
    public init() {}

    public func sample() -> VolumeState {
        var defaultOutputDeviceID = AudioObjectID(kAudioObjectUnknown)
        var propertySize = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &defaultOutputDeviceID
        )

        guard status == noErr, defaultOutputDeviceID != kAudioObjectUnknown else {
            return VolumeState(percent: 50, isMuted: false)
        }

        // Read Volume
        var volume: Float32 = 0.5
        var volSize = UInt32(MemoryLayout<Float32>.size)
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var volStatus = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &volAddress,
            0,
            nil,
            &volSize,
            &volume
        )

        if volStatus != noErr {
            // Fallback to channel 1 or volume scalar
            volAddress.mSelector = kAudioDevicePropertyVolumeScalar
            volAddress.mElement = 1
            volStatus = AudioObjectGetPropertyData(
                defaultOutputDeviceID,
                &volAddress,
                0,
                nil,
                &volSize,
                &volume
            )
        }

        // Read Mute
        var isMutedInt: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let muteStatus = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &muteAddress,
            0,
            nil,
            &muteSize,
            &isMutedInt
        )

        let isMuted = (muteStatus == noErr) && (isMutedInt != 0)
        let percent = VolumeMath.percent(scalar: Double(volume))

        return VolumeState(percent: percent, isMuted: isMuted)
    }
}
