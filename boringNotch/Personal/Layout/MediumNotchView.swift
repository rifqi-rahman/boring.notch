//
//  MediumNotchView.swift
//  boringNotch
//
//  The hover glance. Shows only what matters right now, in priority order:
//  an active call, playing music, a running timer, then a quick overview.
//  Clicking the notch expands to the large view.
//

import Defaults
import SwiftUI

struct MediumNotchView: View {
    @ObservedObject private var music = MusicManager.shared
    @ObservedObject private var pomodoro = PomodoroManager.shared
    @ObservedObject private var call = CallIslandManager.shared
    let albumArtNamespace: Namespace.ID
    let horizontalMediaGestureFeedback: CGFloat

    private enum Content { case call, music, timer, overview }

    private var content: Content {
        if call.callApp != nil, Defaults[.callIslandEnabled] { return .call }
        if music.isPlaying { return .music }
        if pomodoro.isActive { return .timer }
        if !music.isPlayerIdle { return .music }
        return .overview
    }

    var body: some View {
        switch content {
        case .call:
            CallGlance().frame(width: 336)
        case .music:
            CompactHomeView(albumArtNamespace: albumArtNamespace,
                            horizontalMediaGestureFeedback: horizontalMediaGestureFeedback)
                .frame(width: 336)
        case .timer:
            TimerGlance().frame(width: 336)
        case .overview:
            OverviewGlance().frame(width: 360)
        }
    }
}

private struct CallGlance: View {
    @ObservedObject private var call = CallIslandManager.shared
    @ObservedObject private var mic = MicMuteManager.shared

    var body: some View {
        HStack(spacing: 12) {
            if let icon = call.callApp?.icon {
                Image(nsImage: icon).resizable().frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(call.callApp?.localizedName ?? "Call")
                    .font(.system(size: 14, weight: .semibold))
                if let start = call.startedAt {
                    Text(start, style: .timer)
                        .font(.system(size: 12, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                }
            }
            Spacer()
            CircleAction(icon: mic.isMuted ? "mic.slash.fill" : "mic.fill", tint: mic.isMuted ? .red : .white) {
                mic.toggle()
            }
            CircleAction(icon: "arrow.up.forward.app.fill", tint: .green) {
                call.bringAppForward()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct TimerGlance: View {
    @ObservedObject private var pomodoro = PomodoroManager.shared

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: pomodoro.progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: pomodoro.cycle.phase.symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text(pomodoro.cycle.phase.label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(pomodoro.remainingText)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer()
            CircleAction(icon: pomodoro.isRunning ? "pause.fill" : "play.fill", tint: .white) {
                pomodoro.startOrPause()
            }
            CircleAction(icon: "arrow.counterclockwise", tint: .white) { pomodoro.reset(); pomodoro.start() }
                .help("Restart this phase")
            CircleAction(icon: "xmark", tint: .white) { pomodoro.reset() }
                .help("Stop timer")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var color: Color { pomodoro.cycle.phase == .focus ? .effectiveAccent : .green }
}

/// Nothing playing or running: today's events, to-do and shortcuts.
private struct OverviewGlance: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var calendar = CalendarManager.shared
    @ObservedObject private var todos = TodoStore.shared
    @ObservedObject private var pomodoro = PomodoroManager.shared
    @ObservedObject private var caffeine = CaffeineManager.shared

    private var upcoming: [EventModel] {
        calendar.events.filter { !$0.isAllDay && $0.end > .now }.sorted { $0.start < $1.start }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                glanceCard(destination: .calendar) {
                    Label("Today", systemImage: "calendar")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if upcoming.isEmpty {
                        Text("No more events").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    ForEach(upcoming.prefix(2), id: \.id) { event in
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color(nsColor: event.calendar.color))
                                .frame(width: 3, height: 22)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(event.title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                                Text(event.start.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                glanceCard(destination: .calendar) {
                    Label("To-Do", systemImage: "checklist")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if todos.items.isEmpty {
                        Text("Nothing to do").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    ForEach(todos.sorted.prefix(3)) { item in
                        Button { todos.toggle(item) } label: {
                            HStack(spacing: 5) {
                                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.done ? Color.effectiveAccent : .secondary)
                                Text(item.title).strikethrough(item.done).lineLimit(1)
                            }
                            .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 74)

            HStack(spacing: 6) {
                shortcut(pomodoro.isActive ? (pomodoro.isRunning ? "pause.fill" : "play.fill") : "timer",
                         on: pomodoro.isRunning, tint: .effectiveAccent, help: "Focus timer") {
                    pomodoro.startOrPause()
                }
                shortcut("cup.and.saucer.fill", on: caffeine.isActive, tint: .orange, help: "Caffeine") {
                    caffeine.isActive ? caffeine.deactivate()
                        : caffeine.activate(for: CaffeineManager.Duration(rawValue: Defaults[.caffeineDefaultDuration]) ?? .indefinite)
                }
                shortcut("computermouse.fill", on: false, tint: .white, help: "Devices") { open(.tools) }
                shortcut("web.camera.fill", on: false, tint: .white, help: "Speaker & camera") { open(.audio) }
                shortcut("gearshape.fill", on: false, tint: .white, help: "Settings") {
                    SettingsWindowController.shared.showWindow()
                }
            }
            .frame(height: 30)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .task { await calendar.updateCurrentDate(.now) }
    }

    /// Switches to the large view on the given tab.
    private func open(_ view: NotchViews) {
        withAnimation(.smooth) {
            BoringViewCoordinator.shared.currentView = view
            vm.openSize = .large
        }
    }

    private func glanceCard<Content: View>(destination: NotchViews, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) { content() }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture { open(destination) }
    }

    private func shortcut(_ icon: String, on: Bool, tint: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 10).fill(on ? tint : Color.white.opacity(0.06)))
                .foregroundStyle(on ? Color.black : Color.white.opacity(0.85))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct CircleAction: View {
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.1)))
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }
}
