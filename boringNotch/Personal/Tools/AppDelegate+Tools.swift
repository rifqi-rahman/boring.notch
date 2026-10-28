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

        _ = ToolsActivityState.shared
        Task { @MainActor in
            for await _ in Defaults.updates([.cameraGuardEnabled, .micGuardEnabled]) {
                CameraGuardManager.shared.setMonitoring(Defaults[.cameraGuardEnabled] || Defaults[.micGuardEnabled])
            }
        }
    }
}
