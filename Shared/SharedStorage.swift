import Foundation

enum SharedStorage {
    static var directory: URL? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    }

    static func load<T: Decodable>(_ name: String, default fallback: T) -> T {
        guard let directory, let data = try? Data(contentsOf: directory.appendingPathComponent(name)),
              let result = try? APIJSON.decoder().decode(T.self, from: data) else { return fallback }
        return result
    }

    static func save<T: Encodable>(_ value: T, name: String) throws {
        guard let directory else { throw CocoaError(.fileWriteNoPermission) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try APIJSON.encoder().encode(value).write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    static var snapshot: Snapshot { load("snapshot.json", default: Snapshot()) }
    static var personal: PersonalUsage { load("personal.json", default: PersonalUsage()) }
}
