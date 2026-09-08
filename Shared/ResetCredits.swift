import Foundation

struct ResetCredits: Codable, Sendable {
    var availableCount: Int?
    var expirations: [Date] = []
    var fetchedAt: Date?
    var error: String?
    var usage: PersonalUsage?
    var attemptedAt: Date?

    func count(at now: Date) -> Int? {
        availableCount.map { max(0, $0 - expirations.filter { $0 <= now }.count) }
    }
    func nextExpiry(at now: Date) -> Date? { expirations.filter { $0 > now }.min() }
    func isStale(at now: Date) -> Bool {
        error != nil || fetchedAt.map { now.timeIntervalSince($0) > 900 } ?? true
    }
}
