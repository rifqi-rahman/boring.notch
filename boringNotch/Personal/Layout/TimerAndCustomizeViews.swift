//
//  TimerAndCustomizeViews.swift
//  boringNotch
//
//  The Timer tab (Pomodoro with in-notch settings) and the "…" customize
//  page that picks Home widgets and visible tabs.
//

import Defaults
import SwiftUI

struct TimerView: View {
    @Default(.pomodoroFocusMinutes) private var focus
    @Default(.pomodoroShortBreakMinutes) private var shortBreak
    @Default(.pomodoroLongBreakMinutes) private var longBreak
    @Default(.pomodoroSessionsBeforeLongBreak) private var sessions
    @Default(.pomodoroAutoStartNext) private var autoStart
    @Default(.pomodoroKeepAwake) private var keepAwake

    var body: some View {
        WithInNotchSettings {
            CompactPomodoro(focus: focus, shortBreak: shortBreak, longBreak: longBreak, sessions: sessions)
                .padding(.trailing, 30)
        } settings: {
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 4) {
                    NotchSettingRow(label: "Focus") { NotchStepper(value: $focus, range: 5...120, step: 5, suffix: "m") }
                    NotchSettingRow(label: "Short break") { NotchStepper(value: $shortBreak, range: 1...30, suffix: "m") }
                    NotchSettingRow(label: "Long break") { NotchStepper(value: $longBreak, range: 5...60, step: 5, suffix: "m") }
                }
                VStack(spacing: 4) {
                    NotchSettingRow(label: "Long break every") { NotchStepper(value: $sessions, range: 2...8) }
                    NotchToggle(label: "Auto-start next", isOn: $autoStart)
                    NotchToggle(label: "Keep Mac awake", isOn: $keepAwake)
                }
            }
            .padding(.top, 6)
        }
    }
}

struct CustomizeView: View {
    @Default(.hiddenTabs) private var hiddenTabs

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                section("Tabs") {
                    chips(allTabs.filter { $0.view != .home }.map { ($0.label, $0.label, $0.icon) },
                          isOn: { !hiddenTabs.contains($0) },
                          toggle: toggleTab)
                }
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func chips(_ items: [(id: String, label: String, icon: String)],
                       isOn: @escaping (String) -> Bool,
                       toggle: @escaping (String) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.id) { item in
                let on = isOn(item.id)
                Button { toggle(item.id) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: item.icon)
                        Text(item.label)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Capsule().fill(on ? Color.white.opacity(0.9) : Color.white.opacity(0.08)))
                    .foregroundStyle(on ? .black : .white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleTab(_ label: String) {
        if let index = hiddenTabs.firstIndex(of: label) {
            hiddenTabs.remove(at: index)
        } else {
            hiddenTabs.append(label)
        }
    }
}

/// One-row Pomodoro: ring, time, controls, session dots and plan.
private struct CompactPomodoro: View {
    @ObservedObject private var pomodoro = PomodoroManager.shared
    let focus: Int
    let shortBreak: Int
    let longBreak: Int
    let sessions: Int

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: pomodoro.progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: pomodoro.progress)
                VStack(spacing: 0) {
                    Text(pomodoro.remainingText)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(pomodoro.cycle.phase.label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(color)
                }
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button { pomodoro.startOrPause() } label: {
                        Label(pomodoro.isRunning ? "Pause" : "Start", systemImage: pomodoro.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .frame(height: 30)
                            .background(Capsule().fill(color))
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                    NotchIconButton(icon: "forward.end.fill") { pomodoro.skip() }
                    NotchIconButton(icon: "arrow.counterclockwise") { pomodoro.reset() }
                }
                HStack(spacing: 5) {
                    ForEach(0..<sessions, id: \.self) { index in
                        Circle()
                            .fill(index < pomodoro.cycle.completedFocus ? color : Color.white.opacity(0.15))
                            .frame(width: 7, height: 7)
                    }
                }
                Text("Focus \(focus)m · Break \(shortBreak)m · Long \(longBreak)m")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var color: Color { pomodoro.cycle.phase == .focus ? .effectiveAccent : .green }
}
