//
//  NotchLayout.swift
//  boringNotch
//
//  Three notch sizes:
//  - small:  closed notch + live activities (glance while working)
//  - medium: hover glance, the one thing that matters right now
//  - large:  click, tabs + in-notch settings
//

import Defaults
import SwiftUI

enum NotchOpenSize {
    case medium, large
}

/// Widgets the Home dashboard can show, configured from the "…" page.
enum HomeWidget: String, CaseIterable, Identifiable {
    case music, timer, ai, calendar, stats, clipboard, devices

    var id: String { rawValue }

    var label: String {
        switch self {
        case .music: "Music"
        case .timer: "Timer"
        case .ai: "AI Usage"
        case .calendar: "Calendar"
        case .stats: "CPU & Memory"
        case .clipboard: "Clipboard"
        case .devices: "Device Batteries"
        }
    }

    var icon: String {
        switch self {
        case .music: "music.note"
        case .timer: "timer"
        case .ai: "gauge.with.dots.needle.67percent"
        case .calendar: "calendar"
        case .stats: "cpu"
        case .clipboard: "doc.on.clipboard"
        case .devices: "computermouse"
        }
    }

    /// Tab opened when the widget is tapped.
    var destination: NotchViews? {
        switch self {
        case .music: .music
        case .timer: .timer
        case .ai: .aiUsage
        case .clipboard: .clipboard
        case .stats, .devices: .tools
        case .calendar: .music
        }
    }

    static var enabled: [HomeWidget] {
        Defaults[.homeWidgets].compactMap(HomeWidget.init(rawValue:))
    }
}

// MARK: - Shared pieces

/// Small round button used for the in-notch settings gear and similar.
struct NotchIconButton: View {
    let icon: String
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(active ? 0.22 : 0.08)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? .white : .secondary)
    }
}

/// Wraps a tab's content with a gear that flips to its in-notch settings.
struct WithInNotchSettings<Content: View, Settings: View>: View {
    @State private var showSettings = false
    @ViewBuilder var content: Content
    @ViewBuilder var settings: Settings

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if showSettings {
                    ScrollView(.vertical, showsIndicators: false) {
                        settings
                            .padding(.trailing, 32)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .transition(.opacity)
                } else {
                    content.transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            NotchIconButton(icon: showSettings ? "checkmark" : "gearshape.fill", active: showSettings) {
                withAnimation(.smooth(duration: 0.2)) { showSettings.toggle() }
            }
            .padding(.top, 2)
        }
    }
}

/// Compact labelled row for in-notch settings.
struct NotchSettingRow<Control: View>: View {
    let label: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack {
            Text(label).font(.system(size: 12))
            Spacer(minLength: 8)
            control
        }
        .frame(height: 24)
    }
}

/// − value + stepper sized for the notch.
struct NotchStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    var suffix = ""

    var body: some View {
        HStack(spacing: 6) {
            NotchIconButton(icon: "minus") { value = max(range.lowerBound, value - step) }
            Text("\(value)\(suffix)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(minWidth: 44)
            NotchIconButton(icon: "plus") { value = min(range.upperBound, value + step) }
        }
    }
}

struct NotchToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        NotchSettingRow(label: label) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }
}
