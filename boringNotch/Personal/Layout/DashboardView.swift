//
//  DashboardView.swift
//  boringNotch
//
//  Home tab: a row of shortcut widgets. Each one opens its full tab.
//

import Defaults
import SwiftUI

struct DashboardView: View {
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @Default(.homeWidgets) private var widgetIDs

    private var widgets: [HomeWidget] { widgetIDs.compactMap(HomeWidget.init(rawValue:)) }

    var body: some View {
        HStack(spacing: 10) {
            if widgets.isEmpty {
                ToolTile {
                    Text("Add widgets from the ⋯ button")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(widgets.prefix(4)) { widget in
                widgetView(widget)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let destination = widget.destination {
                            withAnimation(.smooth) { coordinator.currentView = destination }
                        }
                    }
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func widgetView(_ widget: HomeWidget) -> some View {
        switch widget {
        case .music: MusicWidget()
        case .timer: TimerWidget()
        case .ai: AIWidget()
        case .calendar: CalendarWidget()
        case .stats: SystemStatsTile()
        case .clipboard: ClipboardWidget()
        case .devices: DevicesWidget()
        }
    }
}

/// Title row shared by the widgets.
private struct WidgetHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
    }
}

private struct MusicWidget: View {
    @ObservedObject private var music = MusicManager.shared

    var body: some View {
        ToolTile {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(nsImage: music.albumArt)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(music.isPlayerIdle ? "Nothing playing" : music.songTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text(music.artistName)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 14) {
                    Spacer()
                    Button { music.previousTrack() } label: { Image(systemName: "backward.fill") }
                    Button { music.togglePlay() } label: {
                        Image(systemName: music.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 16))
                    }
                    Button { music.nextTrack() } label: { Image(systemName: "forward.fill") }
                    Spacer()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
            }
        }
    }
}

private struct TimerWidget: View {
    @ObservedObject private var pomodoro = PomodoroManager.shared

    var body: some View {
        ToolTile {
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeader(icon: pomodoro.cycle.phase.symbol, title: pomodoro.cycle.phase.label)
                Text(pomodoro.remainingText)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Spacer(minLength: 0)
                HStack {
                    ProgressView(value: pomodoro.progress)
                        .tint(pomodoro.cycle.phase == .focus ? Color.effectiveAccent : .green)
                    NotchIconButton(icon: pomodoro.isRunning ? "pause.fill" : "play.fill", active: pomodoro.isRunning) {
                        pomodoro.startOrPause()
                    }
                }
            }
        }
    }
}

private struct AIWidget: View {
    @ObservedObject private var ai = AIUsageManager.shared

    var body: some View {
        ToolTile {
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeader(icon: "gauge.with.dots.needle.67percent", title: "AI Usage")
                ForEach(ai.usage.prefix(3)) { usage in
                    HStack(spacing: 6) {
                        Text(usage.provider.name)
                            .font(.system(size: 11))
                            .frame(width: 64, alignment: .leading)
                        if usage.error != nil {
                            Text("—").foregroundStyle(.secondary)
                        } else {
                            ProgressView(value: min(usage.peakPercent / 100, 1))
                                .tint(usage.peakPercent < 60 ? .green : usage.peakPercent < 85 ? .orange : .red)
                            Text("\(Int(usage.peakPercent))%")
                                .font(.system(size: 10))
                                .monospacedDigit()
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .onAppear { ai.refreshIfStale(maxAge: 300) }
    }
}

private struct CalendarWidget: View {
    var body: some View {
        ToolTile {
            VStack(alignment: .leading, spacing: 4) {
                WidgetHeader(icon: "calendar", title: Date.now.formatted(.dateTime.weekday(.wide)))
                Text(Date.now.formatted(.dateTime.day()))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                Text(Date.now.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ClipboardWidget: View {
    @ObservedObject private var clipboard = ClipboardHistoryManager.shared

    var body: some View {
        ToolTile {
            VStack(alignment: .leading, spacing: 5) {
                WidgetHeader(icon: "doc.on.clipboard", title: "Clipboard")
                ForEach(clipboard.history.entries.prefix(3)) { entry in
                    Text(entry.kind == .image ? (entry.ocrText ?? "Image") : entry.text)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .onTapGesture { clipboard.copy(entry, paste: false) }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DevicesWidget: View {
    @ObservedObject private var batteries = DeviceBatteryManager.shared

    var body: some View {
        ToolTile {
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeader(icon: "battery.75percent", title: "Devices")
                if batteries.devices.isEmpty {
                    Text("No devices").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                ForEach(batteries.devices.prefix(3)) { device in
                    HStack(spacing: 6) {
                        Image(systemName: device.symbol).frame(width: 14)
                        Text(device.name).lineLimit(1)
                        Spacer(minLength: 2)
                        Text("\(device.percent)%").monospacedDigit().foregroundStyle(.secondary)
                    }
                    .font(.system(size: 11))
                }
                Spacer(minLength: 0)
            }
        }
    }
}
