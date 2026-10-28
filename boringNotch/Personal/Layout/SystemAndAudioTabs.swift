//
//  SystemAndAudioTabs.swift
//  boringNotch
//
//  Dedicated tabs that replace the old mixed Tools tab:
//  System (CPU, memory, device batteries, Caffeine) and
//  Audio (output devices, mic mute, privacy alerts).
//

import Defaults
import SwiftUI

struct SystemTab: View {
    @ObservedObject private var caffeine = CaffeineManager.shared
    @ObservedObject private var batteries = DeviceBatteryManager.shared
    @Default(.caffeineDefaultDuration) private var caffeineDuration
    @Default(.deviceBatteryEnabled) private var showDevices
    @Default(.deviceBatteryLowThreshold) private var lowThreshold
    @Default(.windowSnapEnabled) private var snapping
    @Default(.hideNotchEnabled) private var hideNotch
    @Default(.downloadAlertsEnabled) private var downloads

    var body: some View {
        WithInNotchSettings {
            HStack(spacing: 10) {
                SystemStatsTile()
                ToolTile {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Devices", systemImage: "battery.75percent")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        if batteries.devices.isEmpty {
                            Text(showDevices ? "No devices connected" : "Turned off")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        ForEach(batteries.devices.prefix(3)) { device in
                            HStack(spacing: 6) {
                                Image(systemName: device.symbol).frame(width: 14)
                                Text(device.name).lineLimit(1)
                                Spacer(minLength: 2)
                                Text("\(device.percent)%").monospacedDigit()
                                    .foregroundStyle(device.percent <= lowThreshold ? .red : .secondary)
                            }
                            .font(.system(size: 11))
                        }
                        Spacer(minLength: 0)
                    }
                }
                ToolTile {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Caffeine", systemImage: caffeine.isActive ? "cup.and.heat.waves.fill" : "cup.and.saucer")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(caffeine.isActive ? .orange : .secondary)
                        Text(caffeineStatus)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Spacer(minLength: 0)
                        HStack(spacing: 4) {
                            ForEach(CaffeineManager.Duration.allCases, id: \.self) { duration in
                                Button { caffeine.activate(for: duration) } label: {
                                    Text(duration.shortLabel)
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .frame(height: 20)
                                        .background(Capsule().fill(Color.white.opacity(0.1)))
                                }
                                .buttonStyle(.plain)
                            }
                            if caffeine.isActive {
                                NotchIconButton(icon: "xmark") { caffeine.deactivate() }
                            }
                        }
                    }
                }
            }
            .padding(.top, 4)
        } settings: {
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 4) {
                    NotchToggle(label: "Device batteries", isOn: $showDevices)
                    NotchSettingRow(label: "Low battery at") { NotchStepper(value: $lowThreshold, range: 5...50, step: 5, suffix: "%") }
                    NotchToggle(label: "Download alerts", isOn: $downloads)
                }
                VStack(spacing: 4) {
                    NotchToggle(label: "Window snapping", isOn: $snapping)
                    NotchToggle(label: "Hide the notch", isOn: $hideNotch)
                }
            }
            .padding(.top, 6)
        }
    }

    private var caffeineStatus: String {
        guard caffeine.isActive else { return "Off" }
        guard let endsAt = caffeine.endsAt else { return "On" }
        return "Until \(endsAt.formatted(date: .omitted, time: .shortened))"
    }
}

/// Speaker & Camera: output devices, camera mirror and mic mute in one tab.
struct AudioTab: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var routes = AudioRouteManager.shared
    @ObservedObject private var mic = MicMuteManager.shared
    @Default(.cameraGuardEnabled) private var cameraGuard
    @Default(.micGuardEnabled) private var micGuard
    @Default(.callIslandEnabled) private var callIsland
    @Default(.showMicMutedActivity) private var mutedActivity

    var body: some View {
        WithInNotchSettings {
            HStack(spacing: 10) {
                ToolTile {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Output", systemImage: "speaker.wave.2.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(routes.devices) { device in
                                    Button { routes.select(device) } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: device.iconName).frame(width: 16)
                                            Text(device.name).lineLimit(1)
                                            Spacer(minLength: 4)
                                            if device.id == routes.activeDeviceID {
                                                Image(systemName: "checkmark").foregroundStyle(Color.effectiveAccent)
                                            }
                                        }
                                        .font(.system(size: 12))
                                        .padding(.vertical, 4)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                ToolTile {
                    ZStack {
                        if vm.camera.isSessionRunning {
                            CameraPreviewView(camera: vm.camera)
                                .scaledToFill()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: "web.camera")
                                    .font(.system(size: 22))
                                Text(vm.camera.cameraAvailable ? "Mirror" : "No camera")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { vm.toggleCameraPreview() }
                }
                .frame(width: 170)
                ToolTile {
                    VStack(spacing: 8) {
                        Button { mic.toggle() } label: {
                            Image(systemName: mic.isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .frame(width: 54, height: 54)
                                .background(Circle().fill(mic.isMuted ? Color.red : Color.white.opacity(0.12)))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        Text(mic.isMuted ? "Mic muted" : "Mic live")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(mic.isMuted ? .red : .secondary)
                    }
                }
                .frame(width: 110)
            }
            .padding(.top, 4)
            .padding(.trailing, 30)
            .onAppear { routes.refreshDevices() }
        } settings: {
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 4) {
                    NotchToggle(label: "Camera in use alert", isOn: $cameraGuard)
                    NotchToggle(label: "Mic in use alert", isOn: $micGuard)
                }
                VStack(spacing: 4) {
                    NotchToggle(label: "Call island", isOn: $callIsland)
                    NotchToggle(label: "Show muted mic in notch", isOn: $mutedActivity)
                }
            }
            .padding(.top, 6)
        }
    }
}
