//
//  CallIslandManager.swift
//  boringNotch
//
//  macOS has no public API for incoming calls, so a "call" is: the microphone
//  is in use while a known calling app is running.
//

import AppKit
import Combine
import Defaults

@MainActor
final class CallIslandManager: ObservableObject {
    static let shared = CallIslandManager()

    /// The app the call is in, while a call is active.
    @Published private(set) var callApp: NSRunningApplication?
    @Published private(set) var startedAt: Date?

    nonisolated static let callApps: [String] = [
        "com.apple.FaceTime",
        "us.zoom.xos",
        "com.microsoft.teams2",
        "com.microsoft.teams",
        "net.whatsapp.WhatsApp",
        "desktop.WhatsApp",
        "com.hnc.Discord",
        "com.tinyspeck.slackmacgap",
        "ru.keepcoder.Telegram",
        "org.whispersystems.signal-desktop",
        "com.cisco.webexmeetingsapp",
        "com.skype.skype",
        "com.facebook.archon",
    ]

    private var cancellable: AnyCancellable?

    private init() {}

    func setEnabled(_ enabled: Bool) {
        cancellable = nil
        update(micInUse: false)
        guard enabled else { return }
        cancellable = CameraGuardManager.shared.$micInUse.removeDuplicates()
            .sink { [weak self] in self?.update(micInUse: $0) }
    }

    func bringAppForward() {
        callApp?.activate()
    }

    /// Picks the calling app: frontmost if it is one, else the first running one.
    nonisolated static func pickCallApp(frontmost: String?, running: [String]) -> String? {
        if let frontmost, callApps.contains(frontmost) { return frontmost }
        return callApps.first(where: running.contains)
    }

    private func update(micInUse: Bool) {
        guard micInUse else {
            callApp = nil
            startedAt = nil
            return
        }
        let running = NSWorkspace.shared.runningApplications
        let id = Self.pickCallApp(
            frontmost: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            running: running.compactMap(\.bundleIdentifier))
        guard let id else { return }
        callApp = running.first { $0.bundleIdentifier == id }
        if startedAt == nil { startedAt = Date() }
    }
}
