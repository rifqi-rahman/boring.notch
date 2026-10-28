//
//  ToolsSettingsView.swift
//  boringNotch
//
//  Settings for the Tools tab: Pomodoro, Caffeine, mic mute, system stats
//  and the camera / mic privacy indicator.
//

import Defaults
import SwiftUI

struct ToolsSettingsView: View {
    @Default(.pomodoroFocusMinutes) private var focusMinutes
    @Default(.pomodoroShortBreakMinutes) private var shortBreakMinutes
    @Default(.pomodoroLongBreakMinutes) private var longBreakMinutes
    @Default(.pomodoroSessionsBeforeLongBreak) private var sessions
    @Default(.clipboardHistoryLimit) private var clipboardLimit
    @Default(.deviceBatteryLowThreshold) private var lowBattery
    @Default(.caffeineDefaultDuration) private var caffeineDuration

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .showToolsTab) {
                    Text("Show Tools tab in the notch")
                }
                Defaults.Toggle(key: .showSystemStats) {
                    Text("Show CPU and memory usage")
                }
                Defaults.Toggle(key: .showAudioOutputPicker) {
                    Text("Show audio output switcher")
                }
            } header: {
                Text("General")
            }

            Section {
                Stepper("Focus: \(focusMinutes) min", value: $focusMinutes, in: 5...120, step: 5)
                Stepper("Short break: \(shortBreakMinutes) min", value: $shortBreakMinutes, in: 1...30)
                Stepper("Long break: \(longBreakMinutes) min", value: $longBreakMinutes, in: 5...60, step: 5)
                Stepper("Long break every \(sessions) sessions", value: $sessions, in: 2...8)
                Defaults.Toggle(key: .pomodoroAutoStartNext) {
                    Text("Start the next phase automatically")
                }
                Defaults.Toggle(key: .pomodoroKeepAwake) {
                    Text("Keep Mac awake during focus")
                }
                Defaults.Toggle(key: .showPomodoroActivity) {
                    Text("Show countdown in the closed notch")
                }
            } header: {
                Text("Pomodoro")
            }

            Section {
                Picker("Default duration", selection: $caffeineDuration) {
                    ForEach(CaffeineManager.Duration.allCases) { duration in
                        Text(duration.label).tag(duration.rawValue)
                    }
                }
            } header: {
                Text("Caffeine")
            } footer: {
                Text("Prevents the display from sleeping while active.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                Defaults.Toggle(key: .showMicMutedActivity) {
                    Text("Show indicator in the closed notch while muted")
                }
            } header: {
                Text("Microphone mute")
            } footer: {
                Text("Mutes the default input device for every app. Set a shortcut in Shortcuts.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                Defaults.Toggle(key: .cameraGuardEnabled) {
                    Text("Alert when another app uses the camera")
                }
                Defaults.Toggle(key: .micGuardEnabled) {
                    Text("Alert when the microphone is in use")
                }
            } header: {
                Text("Camera Guard")
            }

            Section {
                Defaults.Toggle(key: .clipboardHistoryEnabled) {
                    Text("Keep clipboard history")
                }
                Defaults.Toggle(key: .clipboardCopiedAlert) {
                    Text("Show \"Copied\" in the notch")
                }
                Defaults.Toggle(key: .clipboardOCREnabled) {
                    Text("Recognize text in copied images")
                }
                Defaults.Toggle(key: .clipboardPasteOnSelect) {
                    Text("Paste immediately when choosing an item")
                }
                Stepper("Keep \(clipboardLimit) items", value: $clipboardLimit, in: 20...1000, step: 20)
            } header: {
                Text("Clipboard")
            } footer: {
                Text("Passwords copied from password managers are skipped. Pinned items are never removed. Pasting immediately needs Accessibility permission.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                Defaults.Toggle(key: .aiUsageEnabled) {
                    Text("Show AI usage tab")
                }
                Defaults.Toggle(key: .aiUsageClaude) {
                    Text("Claude (uses the Claude Code login)")
                }
                Defaults.Toggle(key: .aiUsageCodex) {
                    Text("Codex (uses the Codex CLI login)")
                }
                Defaults.Toggle(key: .aiUsageAntigravity) {
                    Text("Antigravity (experimental)")
                }
            } header: {
                Text("AI Usage")
            } footer: {
                Text("Reads the logins those tools store on this Mac and refreshes every 5 minutes. The usage endpoints are unofficial and can stop working.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                Defaults.Toggle(key: .deviceBatteryEnabled) {
                    Text("Show mouse, keyboard and headphone batteries")
                }
                Stepper("Low battery alert at \(lowBattery)%", value: $lowBattery, in: 5...50, step: 5)
                Defaults.Toggle(key: .callIslandEnabled) {
                    Text("Call island while a call app uses the microphone")
                }
            } header: {
                Text("Devices & Calls")
            }

            Section {
                Defaults.Toggle(key: .hideNotchEnabled) {
                    Text("Hide the notch with a black menu bar band")
                }
                Defaults.Toggle(key: .windowSnapEnabled) {
                    Text("Snap windows by dragging them to the notch")
                }
            } header: {
                Text("Screen")
            } footer: {
                Text("Hide the notch replaces the wallpaper with a copy that has a black band and restores it when turned off. Dynamic wallpapers become a still image. Window snapping needs Accessibility permission.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                Defaults.Toggle(key: .downloadAlertsEnabled) {
                    Text("Show an alert when a download finishes")
                }
            } header: {
                Text("Downloads")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Tools")
    }
}
