//
//  AppDelegate+Tools.swift
//  boringNotch
//
//  Startup wiring for the Tools features: global shortcuts and the
//  camera / mic privacy monitor.
//

import Defaults
import KeyboardShortcuts

extension AppDelegate {
    @MainActor
    func setupToolsFeatures() {
        KeyboardShortcuts.onKeyDown(for: .toggleMicMute) {
            MicMuteManager.shared.toggle()
        }
        KeyboardShortcuts.onKeyDown(for: .toggleCaffeine) {
            let caffeine = CaffeineManager.shared
            if caffeine.isActive {
                caffeine.deactivate()
            } else {
                caffeine.activate(for: CaffeineManager.Duration(rawValue: Defaults[.caffeineDefaultDuration]) ?? .indefinite)
            }
        }
        KeyboardShortcuts.onKeyDown(for: .togglePomodoro) {
            PomodoroManager.shared.startOrPause()
        }

        KeyboardShortcuts.onKeyDown(for: .openClipboard) { [weak self] in
            guard let self, Defaults[.clipboardHistoryEnabled] else { return }
            BoringViewCoordinator.shared.currentView = .clipboard
            if self.vm.notchState == .closed {
                _ = self.vm.open()
            }
        }

        _ = ToolsActivityState.shared
        Task { @MainActor in
            for await enabled in Defaults.updates(.clipboardHistoryEnabled) {
                ClipboardHistoryManager.shared.setEnabled(enabled)
            }
        }
        Task { @MainActor in
            for await _ in Defaults.updates([.aiUsageEnabled, .aiUsageClaude, .aiUsageCodex, .aiUsageAntigravity]) {
                AIUsageManager.shared.setEnabled(Defaults[.aiUsageEnabled])
            }
        }
        Task { @MainActor in
            for await enabled in Defaults.updates(.deviceBatteryEnabled) {
                DeviceBatteryManager.shared.setEnabled(enabled)
            }
        }
        Task { @MainActor in
            for await enabled in Defaults.updates(.hideNotchEnabled) {
                HideNotchManager.shared.setEnabled(enabled)
            }
        }
        Task { @MainActor in
            for await enabled in Defaults.updates(.windowSnapEnabled) {
                WindowSnapManager.shared.setEnabled(enabled)
            }
        }
        Task { @MainActor in
            for await enabled in Defaults.updates(.downloadAlertsEnabled) {
                DownloadWatcher.shared.setEnabled(enabled)
            }
        }
        Task { @MainActor in
            for await _ in Defaults.updates([.cameraGuardEnabled, .micGuardEnabled, .callIslandEnabled]) {
                CameraGuardManager.shared.setMonitoring(
                    Defaults[.cameraGuardEnabled] || Defaults[.micGuardEnabled] || Defaults[.callIslandEnabled])
                CallIslandManager.shared.setEnabled(Defaults[.callIslandEnabled])
            }
        }
    }
}
