//
//  CameraGuardManager.swift
//  boringNotch
//
//  Watches whether another app is using a camera or the microphone, so the
//  notch can show a privacy indicator the moment it starts. Cameras are
//  watched through `AVCaptureDevice.isInUseByAnotherApplication`, which
//  already excludes our own mirror; the microphone through CoreAudio's
//  "running somewhere" flag on the default input device.
//

import AVFoundation
import Combine
import CoreAudio
import Defaults
import Foundation

@MainActor
final class CameraGuardManager: ObservableObject {
    static let shared = CameraGuardManager()

    @Published private(set) var cameraInUse = false
    @Published private(set) var micInUse = false

    private var cameraObservations: [NSKeyValueObservation] = []
    private var notificationTokens: [NSObjectProtocol] = []
    private var micDevice: AudioDeviceID = 0
    private var micListener: AudioObjectPropertyListenerBlock?
    private var defaultInputListener: AudioObjectPropertyListenerBlock?
    private var isMonitoring = false

    private static var runningAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private static var defaultInputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private init() {}

    func setMonitoring(_ enabled: Bool) {
        enabled ? start() : stop()
    }

    private func start() {
        guard !isMonitoring else { return }
        isMonitoring = true

        observeCameras()
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            notificationTokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.observeCameras() }
            })
        }

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.observeMic() }
        }
        defaultInputListener = listener
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &Self.defaultInputAddress, .main, listener)
        observeMic()
    }

    private func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        cameraObservations.removeAll()
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        notificationTokens.removeAll()
        removeMicListener()
        if let defaultInputListener {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &Self.defaultInputAddress, .main, defaultInputListener)
        }
        defaultInputListener = nil
        cameraInUse = false
        micInUse = false
    }

    // MARK: - Camera

    private func observeCameras() {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera, .deskViewCamera],
            mediaType: .video,
            position: .unspecified
        ).devices

        cameraObservations = devices.map { device in
            device.observe(\.isInUseByAnotherApplication, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.refreshCameraState(devices) }
            }
        }
        refreshCameraState(devices)
    }

    private func refreshCameraState(_ devices: [AVCaptureDevice]) {
        let inUse = devices.contains { $0.isInUseByAnotherApplication }
        if inUse != cameraInUse { cameraInUse = inUse }
    }

    // MARK: - Microphone

    private func observeMic() {
        let device = MicMuteManager.defaultInputDevice()
        if device != micDevice {
            removeMicListener()
            micDevice = device
            if device != 0 {
                let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                    Task { @MainActor in self?.refreshMicState() }
                }
                micListener = listener
                AudioObjectAddPropertyListenerBlock(device, &Self.runningAddress, .main, listener)
            }
        }
        refreshMicState()
    }

    private func removeMicListener() {
        if micDevice != 0, let micListener {
            AudioObjectRemovePropertyListenerBlock(micDevice, &Self.runningAddress, .main, micListener)
        }
        micListener = nil
        micDevice = 0
    }

    private func refreshMicState() {
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(micDevice, &Self.runningAddress, 0, nil, &size, &running)
        let inUse = status == noErr && running != 0
        if inUse != micInUse { micInUse = inUse }
    }
}
