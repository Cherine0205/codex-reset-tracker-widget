import Foundation

/// Reads quota snapshots only. No account credentials or conversation text is persisted.
enum CodexUsageReader {
    private struct Event: Decodable {
        struct Payload: Decodable {
            struct Limits: Decodable {
                struct Window: Decodable {
                    let used_percent: Double
                    let window_minutes: Int?
                    let resets_at: Double?
                }
                let limit_id: String?
                let primary: Window?
                let secondary: Window?
            }
            let type: String
            let rate_limits: Limits?
        }
        let timestamp: Date
        let type: String
        let payload: Payload
    }

    static func parse(line: Data, now: Date = .now) -> PersonalUsage? {
        guard let event = try? APIJSON.decoder().decode(Event.self, from: line),
              event.type == "event_msg", event.payload.type == "token_count",
              let limits = event.payload.rate_limits, limits.limit_id == "codex",
              event.timestamp <= now.addingTimeInterval(300),
              let weekly = [limits.primary, limits.secondary].compactMap({ $0 }).first(where: { $0.window_minutes == 10080 }),
              weekly.used_percent.isFinite, (0...100).contains(weekly.used_percent),
              let reset = weekly.resets_at, reset.isFinite, reset > 0 else { return nil }
        return PersonalUsage(usedPercent: weekly.used_percent,
                             resetAt: Date(timeIntervalSince1970: reset),
                             recordedAt: event.timestamp, source: "codexLocal")
    }

    static func latest(in root: URL, now: Date = .now) throws -> PersonalUsage? {
        let manager = FileManager.default
        // Only the current/recent date partitions, with bounded file count and tail reads.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var files: [(URL, Date)] = []
        for offset in 0..<14 {
            let date = calendar.date(byAdding: .day, value: -offset, to: now)!
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            let relative = String(format: "%04d/%02d/%02d", parts.year!, parts.month!, parts.day!)
            let folder = root.appendingPathComponent(relative)
            guard manager.fileExists(atPath: folder.path) else { continue }
            for url in try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey]) where url.pathExtension == "jsonl" {
                let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
                files.append((url, values.contentModificationDate ?? .distantPast))
            }
        }
        var latest: PersonalUsage?
        for (url, _) in files.sorted(by: { $0.1 > $1.1 }).prefix(32) {
            guard let handle = try? FileHandle(forReadingFrom: url) else { continue }
            defer { try? handle.close() }
            let size = try handle.seekToEnd()
            try handle.seek(toOffset: size > 2_097_152 ? size - 2_097_152 : 0)
            let data = try handle.readToEnd() ?? Data()
            for line in data.split(separator: 0x0A) {
                // Discard conversation lines before decoding; retain only the selected fields.
                guard line.range(of: Data("\"rate_limits\"".utf8)) != nil,
                      let usage = parse(line: Data(line), now: now),
                      let observed = usage.recordedAt else { continue }
                if observed > (latest?.recordedAt ?? .distantPast) { latest = usage }
            }
        }
        return latest
    }
}
