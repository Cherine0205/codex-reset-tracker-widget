import XCTest
@testable import CodexResetCore

final class CodexUsageTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-09-07T10:00:00Z")!
    private func record(bucket: String = "codex", weekly: String = "secondary", time: String = "2026-09-07T09:00:00Z") -> Data {
        Data("""
        {"timestamp":"\(time)","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"\(bucket)","\(weekly)":{"used_percent":42,"window_minutes":10080,"resets_at":1789267048}}}}
        """.utf8)
    }

    func testFindsWeeklyWindowByDuration() throws {
        for slot in ["primary", "secondary"] {
            let usage = try XCTUnwrap(CodexUsageReader.parse(line: record(weekly: slot), now: now))
            XCTAssertEqual(usage.remainingPercent, 58)
            XCTAssertEqual(usage.resetAt.timeIntervalSince1970, 1789267048)
            XCTAssertTrue(usage.isFromCodex)
            XCTAssertTrue(usage.isOld(at: now))
        }
    }

    func testRejectsOtherBucketsAndInvalidRecords() {
        XCTAssertNil(CodexUsageReader.parse(line: record(bucket: "codex-spark"), now: now))
        XCTAssertNil(CodexUsageReader.parse(line: record(time: "2026-09-08T09:00:00Z"), now: now))
        XCTAssertNil(CodexUsageReader.parse(line: Data("partial json".utf8), now: now))
        let shortWindow = String(data: record(), encoding: .utf8)!.replacingOccurrences(of: "10080", with: "300")
        XCTAssertNil(CodexUsageReader.parse(line: Data(shortWindow.utf8), now: now))
    }

    func testLatestUsesObservationTimeAndSkipsMalformedLines() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let day = root.appendingPathComponent("2026/09/07")
        try FileManager.default.createDirectory(at: day, withIntermediateDirectories: true)
        var data = Data("partial line\n".utf8)
        data.append(record(time: "2026-09-07T09:30:00Z"))
        data.append(Data("\n".utf8))
        data.append(record(time: "2026-09-07T08:30:00Z"))
        try data.write(to: day.appendingPathComponent("sample.jsonl"))
        let usage = try XCTUnwrap(CodexUsageReader.latest(in: root, now: now))
        XCTAssertEqual(usage.recordedAt, now.addingTimeInterval(-1800))
    }

    func testLegacyManualRecordStillDecodes() throws {
        let data = Data(#"{"usedPercent":20,"resetAt":"2026-09-14T10:00:00Z","recordedAt":"2026-09-07T10:00:00Z"}"#.utf8)
        let usage = try APIJSON.decoder().decode(PersonalUsage.self, from: data)
        XCTAssertFalse(usage.isFromCodex)
        XCTAssertEqual(usage.remainingPercent, 80)
    }

    func testLocalCodexWhenRequested() throws {
        guard ProcessInfo.processInfo.environment["LIVE_CODEX_TEST"] == "1" else { throw XCTSkip("Opt-in local quota check") }
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")
        let usage = try XCTUnwrap(CodexUsageReader.latest(in: root))
        XCTAssertTrue(usage.isConfigured)
        XCTAssertTrue(usage.isFromCodex)
        XCTAssertTrue((0...100).contains(usage.usedPercent))
    }
}
