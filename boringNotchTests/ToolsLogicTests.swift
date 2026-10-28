//
//  ToolsLogicTests.swift
//  boringNotch
//
//  Covers the pure logic behind the Tools tab: the Pomodoro phase sequence
//  and the CPU usage computation from tick counters.
//

import XCTest
@testable import boringNotch

final class ToolsLogicTests: XCTestCase {

    func testPomodoroAlternatesFocusAndShortBreak() {
        var cycle = PomodoroCycle(sessionsBeforeLongBreak: 4)
        cycle.advance()
        XCTAssertEqual(cycle.phase, .shortBreak)
        XCTAssertEqual(cycle.completedFocus, 1)
        cycle.advance()
        XCTAssertEqual(cycle.phase, .focus)
    }

    func testPomodoroLongBreakAfterConfiguredSessions() {
        var cycle = PomodoroCycle(sessionsBeforeLongBreak: 3)
        var phases: [PomodoroPhase] = []
        for _ in 0..<6 {
            cycle.advance()
            phases.append(cycle.phase)
        }
        XCTAssertEqual(phases, [.shortBreak, .focus, .shortBreak, .focus, .longBreak, .focus])
        XCTAssertEqual(cycle.completedFocus, 0)
    }

    func testCPUUsageFromTicks() {
        let old = CPUTicks(user: 100, system: 50, idle: 850, nice: 0)
        let new = CPUTicks(user: 200, system: 100, idle: 1000, nice: 0)
        // 150 busy of 300 elapsed.
        XCTAssertEqual(CPUTicks.usage(from: old, to: new), 0.5, accuracy: 0.0001)
    }

    func testCPUUsageWithoutElapsedTicksIsZero() {
        let ticks = CPUTicks(user: 10, system: 10, idle: 10, nice: 0)
        XCTAssertEqual(CPUTicks.usage(from: ticks, to: ticks), 0)
    }
}
