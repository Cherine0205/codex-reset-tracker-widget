import XCTest
@testable import CodexResetCore

final class CoreTests: XCTestCase {
    func testAPIDatesAndUnknownFields() throws {
        let data = Data(#"{"updated_at":"2026-09-07T06:30:48.593Z","last_reset_at":"2026-08-31T02:34:27Z","probabilities":{"rounded_24h":25,"rounded_48h":45},"confidence":"low","new_server_field":42}"#.utf8)
        let forecast = try APIJSON.decoder().decode(Forecast.self, from: data)
        XCTAssertEqual(forecast.probabilities.rounded_24h, 25)
        XCTAssertNotNil(forecast.last_reset_at)
    }

    func testExpiredUsageRequiresManualUpdate() {
        let now = Date()
        let usage = PersonalUsage(usedPercent: 80, resetAt: now.addingTimeInterval(-1), recordedAt: now.addingTimeInterval(-3600))
        XCTAssertTrue(usage.needsUpdate(at: now))
        XCTAssertEqual(usage.remainingPercent, 20)
    }

    func testCacheStalenessAndRoundTrip() throws {
        let now = Date()
        var snapshot = Snapshot(fetchedAt: now)
        XCTAssertFalse(snapshot.isStale(at: now))
        XCTAssertTrue(snapshot.isStale(at: now.addingTimeInterval(1801)))
        snapshot.errors = ["预测更新失败"]
        XCTAssertTrue(snapshot.isStale(at: now))
        let decoded = try APIJSON.decoder().decode(Snapshot.self, from: APIJSON.encoder().encode(snapshot))
        XCTAssertEqual(decoded.errors, snapshot.errors)
    }

    func testLinksAreRestrictedToSourceHosts() {
        XCTAssertNotNil(SourceLink.validated("https://x.com/thsottiaux/status/123"))
        XCTAssertNil(SourceLink.validated("https://x.com.evil.example/path"))
        XCTAssertNil(SourceLink.validated("file:///etc/passwd"))
    }

    func testFailedRequestsPreservePreviousSnapshot() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UnavailableAPI.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let forecast = Forecast(updated_at: .now, last_reset_at: nil,
                                probabilities: .init(rounded_24h: 25, rounded_48h: 45),
                                confidence: "low", confidence_note: nil)
        let previous = Snapshot(forecast: forecast, fetchedAt: .now)
        let result = await ResetAPI(session: session).refresh(previous: previous)
        XCTAssertEqual(result.forecast?.probabilities.rounded_24h, 25)
        XCTAssertEqual(result.fetchedAt, previous.fetchedAt)
        XCTAssertEqual(result.errors.count, 3)
        XCTAssertTrue(result.isStale())
    }

    func testLiveEndpointsWhenRequested() async throws {
        guard ProcessInfo.processInfo.environment["LIVE_API_TEST"] == "1" else {
            throw XCTSkip("Set LIVE_API_TEST=1 to validate live API contracts")
        }
        let snapshot = await ResetAPI().refresh(previous: Snapshot())
        XCTAssertTrue(snapshot.errors.isEmpty, snapshot.errors.joined(separator: ", "))
        XCTAssertFalse(snapshot.feed?.tweets.isEmpty ?? true)
        XCTAssertFalse(snapshot.history?.events.isEmpty ?? true)
        XCTAssertNotNil(snapshot.forecast)
    }
}

private final class UnavailableAPI: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
