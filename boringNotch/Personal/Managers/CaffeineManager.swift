//
//  CaffeineManager.swift
//  boringNotch
//
//  Keeps the display (and therefore the Mac) awake with an IOKit power
//  assertion, like Caffeine / Amphetamine. Optionally for a fixed duration.
//

import Combine
import Foundation
import IOKit.pwr_mgt

@MainActor
final class CaffeineManager: ObservableObject {
    static let shared = CaffeineManager()

    enum Duration: Int, CaseIterable, Identifiable {
        case indefinite = 0
        case minutes15 = 15
        case minutes30 = 30
        case hour1 = 60
        case hours2 = 120

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .indefinite: "Indefinitely"
            case .minutes15: "15 minutes"
            case .minutes30: "30 minutes"
            case .hour1: "1 hour"
            case .hours2: "2 hours"
            }
        }

        var shortLabel: String {
            switch self {
            case .indefinite: "∞"
            case .minutes15: "15m"
            case .minutes30: "30m"
            case .hour1: "1h"
            case .hours2: "2h"
            }
        }
    }

    @Published private(set) var isActive = false
    /// nil when the assertion has no end time.
    @Published private(set) var endsAt: Date?

    private var assertionID: IOPMAssertionID = 0
    private var expiryTask: Task<Void, Never>?

    private init() {}

    func toggle() {
        isActive ? deactivate() : activate()
    }

    func activate(for duration: Duration = .indefinite) {
        if assertionID == 0 {
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "boring.notch Caffeine" as CFString,
                &assertionID
            )
            guard result == kIOReturnSuccess else {
                assertionID = 0
                return
            }
        }
        isActive = true

        expiryTask?.cancel()
        guard duration != .indefinite else {
            endsAt = nil
            return
        }
        let seconds = TimeInterval(duration.rawValue * 60)
        endsAt = Date().addingTimeInterval(seconds)
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.deactivate()
        }
    }

    func deactivate() {
        expiryTask?.cancel()
        expiryTask = nil
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        isActive = false
        endsAt = nil
    }
}
