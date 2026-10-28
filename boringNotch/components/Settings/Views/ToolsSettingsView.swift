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
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Tools")
    }
}
