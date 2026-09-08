import XCTest
@testable import CodexResetCore

final class ResetCreditsTests: XCTestCase {
    func testLiveAccountSnapshotDecodesWithUsageTimestamp() throws {
        let json = #"{"availableCount":1,"expirations":[],"fetchedAt":"2026-09-08T01:00:00Z","attemptedAt":"2026-09-08T01:00:00Z","usage":{"usedPercent":2,"resetAt":"2026-09-15T01:00:00Z","recordedAt":"2026-09-08T01:00:00Z","source":"codexAccount"}}"#
        let record = try APIJSON.decoder().decode(ResetCredits.self, from: Data(json.utf8))
        XCTAssertEqual(record.usage?.remainingPercent, 98)
        XCTAssertEqual(record.usage?.recordedAt, record.fetchedAt)
        XCTAssertEqual(record.usage?.isFromCodex, true)
    }
    func testUnknownIsDifferentFromZero() {
        XCTAssertNil(ResetCredits().count(at: .now))
        XCTAssertEqual(ResetCredits(availableCount: 0).count(at: .now), 0)
    }
    func testExpiresLocallyAndKeepsNextExpiry() {
        let now = Date()
        let later = now.addingTimeInterval(3600)
        let credits = ResetCredits(availableCount: 2, expirations: [now, later], fetchedAt: now)
        XCTAssertEqual(credits.count(at: now), 1)
        XCTAssertEqual(credits.nextExpiry(at: now), later)
        XCTAssertEqual(credits.count(at: later), 0)
    }
    func testFailureAndOldRecordsAreMarkedStale() {
        let now = Date()
        XCTAssertFalse(ResetCredits(availableCount: 1, fetchedAt: now).isStale(at: now))
        XCTAssertTrue(ResetCredits(availableCount: 1, fetchedAt: now, error: "failed").isStale(at: now))
        XCTAssertTrue(ResetCredits(availableCount: 1, fetchedAt: now).isStale(at: now.addingTimeInterval(901)))
    }
}
