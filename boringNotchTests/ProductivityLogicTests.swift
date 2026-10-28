//
//  ProductivityLogicTests.swift
//  boringNotchTests
//

import XCTest
@testable import boringNotch

final class ClipboardHistoryTests: XCTestCase {
    private func text(_ value: String) -> ClipboardEntry {
        ClipboardEntry(kind: .text, text: value)
    }

    func testDuplicateMovesToTopAndKeepsPin() {
        var history = ClipboardHistory()
        history.insert(text("a"), limit: 10)
        history.insert(text("b"), limit: 10)
        let a = history.entries[1]
        history.update(a.id) { $0.pinned = true }

        history.insert(text("a"), limit: 10)

        XCTAssertEqual(history.entries.map(\.text), ["a", "b"])
        XCTAssertEqual(history.entries[0].id, a.id)
        XCTAssertTrue(history.entries[0].pinned)
    }

    func testLimitEvictsOldestUnpinnedOnly() {
        var history = ClipboardHistory()
        history.insert(text("old-pinned"), limit: 2)
        history.update(history.entries[0].id) { $0.pinned = true }
        history.insert(text("1"), limit: 2)
        history.insert(text("2"), limit: 2)
        let evicted = history.insert(text("3"), limit: 2)

        XCTAssertEqual(evicted.map(\.text), ["1"])
        XCTAssertEqual(Set(history.entries.map(\.text)), ["3", "2", "old-pinned"])
    }

    func testFilterMatchesOCRTextAndPutsPinnedFirst() {
        var history = ClipboardHistory()
        var image = ClipboardEntry(kind: .image, text: "image:abc")
        image.ocrText = "Invoice total 42"
        history.insert(image, limit: 10)
        history.insert(text("invoice draft"), limit: 10)
        history.update(history.entries[1].id) { $0.pinned = true }

        let results = history.filtered(by: "INVOICE")
        XCTAssertEqual(results.map(\.kind), [.image, .text])
        XCTAssertEqual(history.filtered(by: "total 42").count, 1)
        XCTAssertTrue(history.filtered(by: "nothing").isEmpty)
    }

    func testConcealedTypesAreIgnored() {
        XCTAssertTrue(ClipboardHistory.shouldIgnore(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]))
        XCTAssertFalse(ClipboardHistory.shouldIgnore(types: ["public.utf8-plain-text"]))
    }
}

final class AIUsageParserTests: XCTestCase {
    func testClaudeUsage() throws {
        let json = """
        {"five_hour": {"utilization": 37.0, "resets_at": "2026-10-28T15:00:00.123+00:00"},
         "seven_day": {"utilization": 12, "resets_at": "2026-11-02T09:00:00Z"},
         "seven_day_opus": null, "extra_usage": {"is_enabled": false}}
        """
        let windows = try AIUsageParser.parseClaude(Data(json.utf8))
        XCTAssertEqual(windows.map(\.label), ["5h", "Week"])
        XCTAssertEqual(windows[0].usedPercent, 37)
        XCTAssertNotNil(windows[0].resetsAt)
        XCTAssertNotNil(windows[1].resetsAt)
    }

    func testCodexUsage() throws {
        let json = """
        {"plan_type": "plus", "rate_limit": {"allowed": true,
         "primary_window": {"used_percent": 8, "limit_window_seconds": 18000, "reset_at": 1795748639},
         "secondary_window": {"used_percent": 40, "limit_window_seconds": 604800, "reset_at": 1795748639}}}
        """
        let parsed = try AIUsageParser.parseCodex(Data(json.utf8))
        XCTAssertEqual(parsed.plan, "plus")
        XCTAssertEqual(parsed.windows.map(\.label), ["5h", "Week"])
        XCTAssertEqual(parsed.windows[1].usedPercent, 40)
        XCTAssertEqual(parsed.windows[0].resetsAt, Date(timeIntervalSince1970: 1795748639))
    }

    func testCodexWithoutSecondaryWindow() throws {
        let json = """
        {"rate_limit": {"primary_window": {"used_percent": 0, "limit_window_seconds": 2592000, "reset_at": 1}, "secondary_window": null}}
        """
        let parsed = try AIUsageParser.parseCodex(Data(json.utf8))
        XCTAssertEqual(parsed.windows.map(\.label), ["30d"])
    }

    func testAntigravityQuota() throws {
        let json = """
        {"userStatus": {"cascadeModelConfigData": {"clientModelConfigs": [
          {"label": "Gemini 3 Pro", "quotaInfo": {"remainingFraction": 0.25, "resetTime": "2026-10-28T20:00:00Z"}},
          {"label": "No quota"}]}}}
        """
        let windows = try AIUsageParser.parseAntigravity(Data(json.utf8))
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows[0].usedPercent, 75, accuracy: 0.001)
    }

    func testInvalidJSONThrows() {
        XCTAssertThrowsError(try AIUsageParser.parseClaude(Data("[]".utf8)))
    }
}

final class DownloadDetectorTests: XCTestCase {
    func testRenamedPartialFileIsFinished() {
        let before: Set = ["report.pdf.crdownload", "old.zip"]
        let after: Set = ["report.pdf", "old.zip"]
        XCTAssertEqual(DownloadDetector.finished(previous: before, current: after), ["report.pdf"])
    }

    func testPartialAndHiddenFilesAreIgnored() {
        let after: Set = ["movie.mp4.part", ".DS_Store", "Safari.download"]
        XCTAssertTrue(DownloadDetector.finished(previous: [], current: after).isEmpty)
    }
}
