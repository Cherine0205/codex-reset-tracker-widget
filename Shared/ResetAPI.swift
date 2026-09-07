import Foundation

struct ResetAPI: Sendable {
    var baseURL = SourceLink.home
    var session = URLSession.shared

    func get<T: Decodable & Sendable>(_ path: String, as type: T.Type) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/\(path)"), resolvingAgainstBaseURL: false)!
        if path == "forecast" { components.queryItems = [.init(name: "tz", value: TimeZone.current.identifier)] }
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try APIJSON.decoder().decode(type, from: data)
    }

    private func attempt<T: Decodable & Sendable>(_ path: String, as type: T.Type) async -> Result<T, Error> {
        do { return .success(try await get(path, as: type)) }
        catch { return .failure(error) }
    }

    func refresh(previous: Snapshot) async -> Snapshot {
        async let feed = attempt("feed", as: Feed.self)
        async let forecast = attempt("forecast", as: Forecast.self)
        async let history = attempt("timeline", as: History.self)
        var next = previous
        next.errors = []
        switch await feed {
        case .success(let value): next.feed = value
        case .failure: next.errors.append("公告更新失败")
        }
        switch await forecast {
        case .success(let value): next.forecast = value
        case .failure: next.errors.append("预测更新失败")
        }
        switch await history {
        case .success(let value): next.history = value
        case .failure: next.errors.append("历史更新失败")
        }
        if next.errors.isEmpty { next.fetchedAt = .now }
        return next
    }
}
