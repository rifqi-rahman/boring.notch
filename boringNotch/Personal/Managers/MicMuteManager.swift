//
//  MicMuteManager.swift
//  boringNotch
//
//  System-wide microphone mute: mutes the default input device in CoreAudio
//  so every app (Zoom, Meet, Discord…) hears silence. Devices without a
//  mute control are silenced by zeroing their input volume instead, and the
//  previous volume is restored on unmute. The mute follows the default
//  input when it changes (e.g. AirPods connect mid-call).
//

import Combine
import CoreAudio
import Foundation

@MainActor
final class MicMuteManager: ObservableObject {
    static let shared = MicMuteManager()

    @Published private(set) var isMuted = false

    /// Input volumes we zeroed, to restore on unmute.
    private var savedVolumes: [AudioDeviceID: Float32] = [:]
    private var listening = false

    private static var defaultInputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private init() {
        isMuted = Self.readMute(Self.defaultInputDevice()) ?? false
    }

    func toggle() {
        setMuted(!isMuted)
    }

    func setMuted(_ muted: Bool) {
        let device = Self.defaultInputDevice()
        guard device != 0 else { return }
        apply(muted, to: device)
        isMuted = muted
        startListeningIfNeeded()
    }

    private func apply(_ muted: Bool, to device: AudioDeviceID) {
        if Self.writeMute(device, muted) { return }
        if muted {
            if savedVolumes[device] == nil, let volume = Self.readVolume(device), volume > 0 {
                savedVolumes[device] = volume
            }
            Self.writeVolume(device, 0)
        } else {
            Self.writeVolume(device, savedVolumes.removeValue(forKey: device) ?? 0.75)
        }
    }

    private func startListeningIfNeeded() {
        guard !listening else { return }
        listening = true
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &Self.defaultInputAddress, .main
        ) { [weak self] _, _ in
            Task { @MainActor in
                guard let self, self.isMuted else { return }
                self.apply(true, to: Self.defaultInputDevice())
            }
        }
    }

    // MARK: - CoreAudio

    static func defaultInputDevice() -> AudioDeviceID {
        var device = AudioDeviceID()
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &defaultInputAddress, 0, nil, &size, &device
        )
        return status == noErr ? device : 0
    }

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func isSettable(_ device: AudioDeviceID, _ address: inout AudioObjectPropertyAddress) -> Bool {
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }

    private static func readMute(_ device: AudioDeviceID) -> Bool? {
        var address = address(kAudioDevicePropertyMute)
        guard device != 0, AudioObjectHasProperty(device, &address) else { return nil }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value != 0
    }

    private static func writeMute(_ device: AudioDeviceID, _ muted: Bool) -> Bool {
        var address = address(kAudioDevicePropertyMute)
        guard isSettable(device, &address) else { return false }
        var value: UInt32 = muted ? 1 : 0
        return AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr
    }

    private static func readVolume(_ device: AudioDeviceID) -> Float32? {
        var address = address(kAudioDevicePropertyVolumeScalar)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    @discardableResult
    private static func writeVolume(_ device: AudioDeviceID, _ volume: Float32) -> Bool {
        var address = address(kAudioDevicePropertyVolumeScalar)
        guard isSettable(device, &address) else { return false }
        var value = volume
        return AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value) == noErr
    }
}
