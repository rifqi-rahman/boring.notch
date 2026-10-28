//
//  InNotchSettings.swift
//  boringNotch
//
//  Settings pages shown behind the gear of each tab.
//

import Defaults
import SwiftUI

struct ClipboardTab: View {
    @Default(.clipboardCopiedAlert) private var copiedAlert
    @Default(.clipboardOCREnabled) private var ocr
    @Default(.clipboardPasteOnSelect) private var pasteOnSelect
    @Default(.clipboardHistoryLimit) private var limit

    var body: some View {
        WithInNotchSettings {
            ClipboardView().padding(.trailing, 30)
        } settings: {
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 4) {
                    NotchToggle(label: "Show \"Copied\" in notch", isOn: $copiedAlert)
                    NotchToggle(label: "Read text in images", isOn: $ocr)
                }
                VStack(spacing: 4) {
                    NotchToggle(label: "Paste when choosing", isOn: $pasteOnSelect)
                    NotchSettingRow(label: "Keep") { NotchStepper(value: $limit, range: 20...1000, step: 20) }
                }
            }
            .padding(.top, 6)
        }
    }
}

struct AIUsageTab: View {
    @Default(.aiUsageClaude) private var claude
    @Default(.aiUsageCodex) private var codex
    @Default(.aiUsageAntigravity) private var antigravity

    var body: some View {
        WithInNotchSettings {
            AIUsageView().padding(.trailing, 30)
        } settings: {
            VStack(spacing: 4) {
                NotchToggle(label: "Claude", isOn: $claude)
                NotchToggle(label: "Codex", isOn: $codex)
                NotchToggle(label: "Antigravity (experimental)", isOn: $antigravity)
            }
            .frame(maxWidth: 300)
            .padding(.top, 6)
        }
    }
}

struct ToolsTab: View {
    @Default(.showSystemStats) private var stats
    @Default(.showAudioOutputPicker) private var audioPicker
    @Default(.cameraGuardEnabled) private var cameraGuard
    @Default(.micGuardEnabled) private var micGuard
    @Default(.callIslandEnabled) private var callIsland
    @Default(.downloadAlertsEnabled) private var downloads
    @Default(.deviceBatteryEnabled) private var devices
    @Default(.windowSnapEnabled) private var snapping
    @Default(.hideNotchEnabled) private var hideNotch

    var body: some View {
        WithInNotchSettings {
            ToolsView().padding(.trailing, 30)
        } settings: {
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 4) {
                    NotchToggle(label: "CPU & memory", isOn: $stats)
                    NotchToggle(label: "Audio output picker", isOn: $audioPicker)
                    NotchToggle(label: "Device batteries", isOn: $devices)
                }
                VStack(spacing: 4) {
                    NotchToggle(label: "Camera alert", isOn: $cameraGuard)
                    NotchToggle(label: "Mic alert", isOn: $micGuard)
                    NotchToggle(label: "Call island", isOn: $callIsland)
                }
                VStack(spacing: 4) {
                    NotchToggle(label: "Download alerts", isOn: $downloads)
                    NotchToggle(label: "Window snapping", isOn: $snapping)
                    NotchToggle(label: "Hide the notch", isOn: $hideNotch)
                }
            }
            .padding(.top, 6)
        }
    }
}
