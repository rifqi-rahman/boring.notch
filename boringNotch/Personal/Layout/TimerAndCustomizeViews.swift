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
            HStack(spacing: 10) {
                PomodoroTile()
                ToolTile {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Focus \(focus) min · Break \(shortBreak) min")
                        Text("Long break \(longBreak) min every \(sessions)")
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 4)
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
    @Default(.homeWidgets) private var homeWidgets
    @Default(.hiddenTabs) private var hiddenTabs
    @Default(.hoverOpensMedium) private var hoverOpensMedium

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                section("Home widgets (up to 4)") {
                    chips(HomeWidget.allCases.map { ($0.rawValue, $0.label, $0.icon) },
                          isOn: { homeWidgets.contains($0) },
                          toggle: toggleWidget)
                }
                section("Tabs") {
                    chips(allTabs.filter { $0.view != .home }.map { ($0.label, $0.label, $0.icon) },
                          isOn: { !hiddenTabs.contains($0) },
                          toggle: toggleTab)
                }
                NotchToggle(label: "Hovering shows a compact glance (click for full view)", isOn: $hoverOpensMedium)
                    .frame(maxWidth: 420)
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

    private func toggleWidget(_ id: String) {
        if let index = homeWidgets.firstIndex(of: id) {
            homeWidgets.remove(at: index)
        } else if homeWidgets.count < 4 {
            homeWidgets.append(id)
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
