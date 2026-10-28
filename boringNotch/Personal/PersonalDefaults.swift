//
//  PersonalDefaults.swift
//  boringNotch
//
//  Settings for the features added in this fork, kept apart from
//  Constants.swift so upstream merges stay conflict-free.
//

import Defaults
import Foundation

extension Defaults.Keys {
    // MARK: Tools tab
    static let showToolsTab = Key<Bool>("showToolsTab", default: true)
    static let showSystemStats = Key<Bool>("showSystemStats", default: true)
    static let showAudioOutputPicker = Key<Bool>("showAudioOutputPicker", default: true)

    // MARK: Caffeine
    static let caffeineDefaultDuration = Key<Int>("caffeineDefaultDuration", default: 0)

    // MARK: Mic mute
    static let showMicMutedActivity = Key<Bool>("showMicMutedActivity", default: true)

    // MARK: Pomodoro
    static let pomodoroFocusMinutes = Key<Int>("pomodoroFocusMinutes", default: 25)
    static let pomodoroShortBreakMinutes = Key<Int>("pomodoroShortBreakMinutes", default: 5)
    static let pomodoroLongBreakMinutes = Key<Int>("pomodoroLongBreakMinutes", default: 15)
    static let pomodoroSessionsBeforeLongBreak = Key<Int>("pomodoroSessionsBeforeLongBreak", default: 4)
    static let pomodoroKeepAwake = Key<Bool>("pomodoroKeepAwake", default: false)
    static let pomodoroAutoStartNext = Key<Bool>("pomodoroAutoStartNext", default: false)
    static let showPomodoroActivity = Key<Bool>("showPomodoroActivity", default: true)

    // MARK: Camera guard
    static let cameraGuardEnabled = Key<Bool>("cameraGuardEnabled", default: true)
    static let micGuardEnabled = Key<Bool>("micGuardEnabled", default: true)

    // MARK: Clipboard history
    static let clipboardHistoryEnabled = Key<Bool>("clipboardHistoryEnabled", default: true)
    static let clipboardHistoryLimit = Key<Int>("clipboardHistoryLimit", default: 200)
    static let clipboardOCREnabled = Key<Bool>("clipboardOCREnabled", default: true)
    static let clipboardPasteOnSelect = Key<Bool>("clipboardPasteOnSelect", default: false)
    static let clipboardCopiedAlert = Key<Bool>("clipboardCopiedAlert", default: true)

    // MARK: AI usage
    static let aiUsageEnabled = Key<Bool>("aiUsageEnabled", default: true)
    static let aiUsageClaude = Key<Bool>("aiUsageClaude", default: true)
    static let aiUsageCodex = Key<Bool>("aiUsageCodex", default: true)
    static let aiUsageAntigravity = Key<Bool>("aiUsageAntigravity", default: false)

    // MARK: Download alerts
    static let downloadAlertsEnabled = Key<Bool>("downloadAlertsEnabled", default: true)
}
