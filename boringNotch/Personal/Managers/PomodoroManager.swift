//
//  PomodoroManager.swift
//  boringNotch
//
//  Focus timer: focus → short break, with a long break every N focus
//  sessions. The countdown lives in the closed notch as a live activity.
//

import Combine
import Defaults
import Foundation

enum PomodoroPhase: String, Equatable {
    case focus
    case shortBreak
    case longBreak

    var label: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Break"
        case .longBreak: "Long break"
        }
    }

    var symbol: String {
        switch self {
        case .focus: "brain.head.profile"
        case .shortBreak, .longBreak: "cup.and.saucer.fill"
        }
    }
}

/// The phase sequence, kept free of timers so it can be unit tested.
struct PomodoroCycle: Equatable {
    var phase: PomodoroPhase = .focus
    /// Focus sessions finished since the last long break.
    var completedFocus = 0
    var sessionsBeforeLongBreak = 4

    mutating func advance() {
        switch phase {
        case .focus:
            completedFocus += 1
            if completedFocus >= sessionsBeforeLongBreak {
                completedFocus = 0
                phase = .longBreak
            } else {
                phase = .shortBreak
            }
        case .shortBreak, .longBreak:
            phase = .focus
        }
    }
}

@MainActor
final class PomodoroManager: ObservableObject {
    static let shared = PomodoroManager()

    @Published private(set) var cycle = PomodoroCycle()
    @Published private(set) var isRunning = false
    /// Seconds left; kept while paused.
    @Published private(set) var remaining: TimeInterval = 0
    /// True between pressing start and resetting — paused counts as active.
    @Published private(set) var isActive = false

    private var endsAt: Date?
    private var ticker: Timer?
    private let chime = AudioPlayer()

    private init() {
        remaining = duration(of: .focus)
    }

    var progress: Double {
        let total = duration(of: cycle.phase)
        return total > 0 ? 1 - remaining / total : 0
    }

    var remainingText: String {
        let seconds = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    func duration(of phase: PomodoroPhase) -> TimeInterval {
        switch phase {
        case .focus: TimeInterval(Defaults[.pomodoroFocusMinutes] * 60)
        case .shortBreak: TimeInterval(Defaults[.pomodoroShortBreakMinutes] * 60)
        case .longBreak: TimeInterval(Defaults[.pomodoroLongBreakMinutes] * 60)
        }
    }

    func startOrPause() {
        isRunning ? pause() : start()
    }

    func start() {
        if !isActive {
            cycle.sessionsBeforeLongBreak = Defaults[.pomodoroSessionsBeforeLongBreak]
            remaining = duration(of: cycle.phase)
        }
        isActive = true
        isRunning = true
        endsAt = Date().addingTimeInterval(remaining)
        if cycle.phase == .focus && Defaults[.pomodoroKeepAwake] {
            CaffeineManager.shared.activate()
        }
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func pause() {
        isRunning = false
        ticker?.invalidate()
        ticker = nil
        endsAt = nil
    }

    func reset() {
        pause()
        if Defaults[.pomodoroKeepAwake] { CaffeineManager.shared.deactivate() }
        cycle = PomodoroCycle(sessionsBeforeLongBreak: Defaults[.pomodoroSessionsBeforeLongBreak])
        remaining = duration(of: .focus)
        isActive = false
    }

    /// Ends the current phase now and moves to the next one.
    func skip() {
        finishPhase()
    }

    private func tick() {
        guard let endsAt else { return }
        remaining = max(0, endsAt.timeIntervalSinceNow)
        if remaining <= 0 { finishPhase() }
    }

    private func finishPhase() {
        let wasRunning = isRunning
        pause()
        cycle.advance()
        remaining = duration(of: cycle.phase)
        chime.play(fileName: "boring", fileExtension: "m4a")
        if cycle.phase != .focus && Defaults[.pomodoroKeepAwake] {
            CaffeineManager.shared.deactivate()
        }
        if wasRunning && Defaults[.pomodoroAutoStartNext] {
            start()
        }
    }
}
