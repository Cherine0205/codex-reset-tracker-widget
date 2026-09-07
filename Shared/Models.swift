import Foundation

struct Feed: Codable, Sendable {
    let fetched_at: Date
    let stale: Bool
    let tweets: [Post]
}

struct Post: Codable, Identifiable, Sendable {
    let id: String
    let text: String
    let at: Date
    let url: String
    let kind: String
}

struct Forecast: Codable, Sendable {
    struct Probabilities: Codable, Sendable {
        let rounded_24h: Int?
        let rounded_48h: Int?
    }
    let updated_at: Date
    let last_reset_at: Date?
    let probabilities: Probabilities
    let confidence: String
    let confidence_note: String?
}

struct History: Codable, Sendable {
    let updated_at: Date
    let events: [ResetEvent]
}

struct ResetEvent: Codable, Identifiable, Sendable {
    let id: String
    let summary: String
    let url: String
    let type: String
    let source: String
    let announced_at: Date?
    let reset_verification_status: String?

    var statusLabel: String {
        if source == "archive" { return "站点已核验" }
        return reset_verification_status == "confirmed" ? "站点已确认" : "待核验"
    }
}

struct Snapshot: Codable, Sendable {
    var feed: Feed?
    var forecast: Forecast?
    var history: History?
    var fetchedAt: Date?
    var errors: [String] = []

    func isStale(at date: Date = .now) -> Bool {
        !errors.isEmpty || feed?.stale == true || fetchedAt.map { date.timeIntervalSince($0) > 1800 } ?? true
    }
}

struct PersonalUsage: Codable, Sendable {
    var usedPercent: Double = 0
    var resetAt: Date = .now.addingTimeInterval(7 * 86400)
    var recordedAt: Date?
    var source: String?

    var isConfigured: Bool { recordedAt != nil }
    var isFromCodex: Bool { source == "codexLocal" }
    var sourceLabel: String { isFromCodex ? "Codex 本地记录" : "手动记录" }
    func isOld(at date: Date = .now) -> Bool {
        isFromCodex && (recordedAt.map { date.timeIntervalSince($0) > 1800 } ?? true)
    }
    var remainingPercent: Double { max(0, min(100, 100 - usedPercent)) }
    func needsUpdate(at date: Date = .now) -> Bool { isConfigured && resetAt <= date }
}

enum APIJSON {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { value in
            let raw = try value.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: raw) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: try value.singleValueContainer(), debugDescription: "Invalid date: \(raw)")
        }
        return decoder
    }
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

enum SourceLink {
    static let home = URL(string: "https://codex-reset.com")!
    static func validated(_ raw: String) -> URL? {
        guard let url = URL(string: raw), url.scheme == "https",
              let host = url.host, ["x.com", "twitter.com", "codex-reset.com"].contains(host) else { return nil }
        return url
    }
}
