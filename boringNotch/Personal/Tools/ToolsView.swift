//
//  ToolsView.swift
//  boringNotch
//
//  The "Tools" tab of the open notch: focus timer, quick toggles
//  (Caffeine, mic mute, audio output) and live CPU / memory stats.
//

import Defaults
import SwiftUI

struct ToolsView: View {
    @Default(.showSystemStats) private var showSystemStats
    @Default(.deviceBatteryEnabled) private var showDeviceBattery
    @ObservedObject private var batteries = DeviceBatteryManager.shared

    var body: some View {
        HStack(spacing: 10) {
            PomodoroTile()
            QuickTogglesTile()
            if showSystemStats {
                SystemStatsTile()
            }
            if showDeviceBattery && !batteries.devices.isEmpty {
                DeviceBatteryTile(devices: batteries.devices)
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Rounded dark card shared by every tile.
struct ToolTile<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
    }
}

// MARK: - Pomodoro

struct PomodoroTile: View {
    @ObservedObject private var pomodoro = PomodoroManager.shared

    var body: some View {
        ToolTile {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: pomodoro.progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.5), value: pomodoro.progress)
                    Image(systemName: pomodoro.cycle.phase.symbol)
                        .font(.system(size: 16))
                        .foregroundStyle(ringColor)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text(pomodoro.cycle.phase.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(pomodoro.remainingText)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    HStack(spacing: 6) {
                        HoverButton(icon: pomodoro.isRunning ? "pause.fill" : "play.fill", scale: .medium) {
                            pomodoro.startOrPause()
                        }
                        HoverButton(icon: "forward.end.fill", scale: .small) {
                            pomodoro.skip()
                        }
                        HoverButton(icon: "arrow.counterclockwise", scale: .small) {
                            pomodoro.reset()
                        }
                        .opacity(pomodoro.isActive ? 1 : 0.4)
                    }
                }
            }
        }
    }

    private var ringColor: Color {
        pomodoro.cycle.phase == .focus ? .effectiveAccent : .green
    }
}

// MARK: - Quick toggles

struct QuickTogglesTile: View {
    @ObservedObject private var caffeine = CaffeineManager.shared
    @ObservedObject private var mic = MicMuteManager.shared
    @Default(.showAudioOutputPicker) private var showAudioOutputPicker
    @Default(.caffeineDefaultDuration) private var caffeineDuration

    var body: some View {
        ToolTile {
            VStack(alignment: .leading, spacing: 8) {
                ToggleRow(
                    title: "Caffeine",
                    subtitle: caffeineSubtitle,
                    icon: caffeine.isActive ? "cup.and.heat.waves.fill" : "cup.and.saucer",
                    isOn: caffeine.isActive,
                    tint: .orange
                ) {
                    if caffeine.isActive {
                        caffeine.deactivate()
                    } else {
                        caffeine.activate(for: CaffeineManager.Duration(rawValue: caffeineDuration) ?? .indefinite)
                    }
                }
                ToggleRow(
                    title: "Microphone",
                    subtitle: mic.isMuted ? "Muted" : "Live",
                    icon: mic.isMuted ? "mic.slash.fill" : "mic.fill",
                    isOn: mic.isMuted,
                    tint: .red
                ) {
                    mic.toggle()
                }
                if showAudioOutputPicker {
                    AudioOutputRow()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var caffeineSubtitle: String {
        guard caffeine.isActive else { return "Off" }
        guard let endsAt = caffeine.endsAt else { return "On" }
        return "Until \(endsAt.formatted(date: .omitted, time: .shortened))"
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isOn ? .black : .white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(isOn ? tint : Color.white.opacity(0.12)))
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.caption).fontWeight(.medium)
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AudioOutputRow: View {
    @ObservedObject private var routeManager = AudioRouteManager.shared

    var body: some View {
        HStack(spacing: 8) {
            MediaOutputSlotButton()
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text("Output").font(.caption).fontWeight(.medium)
                Text(routeManager.activeDevice?.name ?? "Choose device")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .onAppear { routeManager.refreshDevices() }
    }
}

// MARK: - System stats

struct SystemStatsTile: View {
    @ObservedObject private var statsManager = SystemStatsManager.shared

    var body: some View {
        ToolTile {
            VStack(alignment: .leading, spacing: 10) {
                StatBar(label: "CPU", value: statsManager.stats.cpu,
                        detail: "\(Int(statsManager.stats.cpu * 100))%")
                StatBar(label: "Memory", value: statsManager.stats.memoryFraction,
                        detail: memoryDetail)
            }
        }
        .onAppear { statsManager.start() }
        .onDisappear { statsManager.stop() }
    }

    private var memoryDetail: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useGB]
        let used = formatter.string(fromByteCount: Int64(statsManager.stats.memoryUsed))
        let total = formatter.string(fromByteCount: Int64(statsManager.stats.memoryTotal))
        return "\(used) / \(total)"
    }
}

private struct StatBar: View {
    let label: String
    let value: Double
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).fontWeight(.medium)
                Spacer()
                Text(detail).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * min(max(value, 0), 1))
                        .animation(.smooth, value: value)
                }
            }
            .frame(height: 6)
        }
    }

    private var color: Color {
        switch value {
        case ..<0.6: .green
        case ..<0.85: .yellow
        default: .red
        }
    }
}

// MARK: - Device batteries

private struct DeviceBatteryTile: View {
    let devices: [DeviceBattery]

    var body: some View {
        ToolTile {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(devices.prefix(4)) { device in
                    HStack(spacing: 6) {
                        Image(systemName: device.symbol)
                            .frame(width: 16)
                        Text(device.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 4)
                        Text("\(device.percent)%")
                            .monospacedDigit()
                            .foregroundStyle(device.percent <= Defaults[.deviceBatteryLowThreshold] ? .red : .secondary)
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                Spacer(minLength: 0)
            }
        }
    }
}
