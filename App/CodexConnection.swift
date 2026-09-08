import AppKit

@MainActor
enum CodexConnection {
    private static let key = "codexSessionsBookmark"
    static var isConnected: Bool { UserDefaults.standard.data(forKey: key) != nil }

    static func chooseFolder() throws -> Bool {
        let panel = NSOpenPanel()
        panel.title = "连接 Codex 本地用量"
        panel.message = "选择 ~/.codex/sessions。仅提取用量和重置时间，不保存或上传对话内容。"
        panel.prompt = "连接"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        guard url.lastPathComponent == "sessions" else {
            throw NSError(domain: "CodexConnection", code: 1, userInfo: [NSLocalizedDescriptionKey: "请选择 Codex 的 sessions 文件夹。"])
        }
        let bookmark = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: key)
        return true
    }

    static func disconnect() { UserDefaults.standard.removeObject(forKey: key) }

    static func read(requestedAfter: Date? = nil) async throws -> (usage: PersonalUsage?, credits: ResetCredits?) {
        guard let bookmark = UserDefaults.standard.data(forKey: key) else { return (nil, nil) }
        var stale = false
        let url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
        guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
        defer { url.stopAccessingSecurityScopedResource() }
        if stale {
            let renewed = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(renewed, forKey: key)
        }
        let creditsURL = url.appendingPathComponent("codex-reset-credits.json")
        var credits: ResetCredits?
        let deadline = Date.now.addingTimeInterval(30)
        repeat {
            credits = (try? Data(contentsOf: creditsURL)).flatMap { try? APIJSON.decoder().decode(ResetCredits.self, from: $0) }
            guard let requestedAfter else { break }
            if (credits?.attemptedAt ?? credits?.fetchedAt ?? .distantPast) >= requestedAfter { break }
            if Date.now >= deadline {
                throw NSError(domain: "CodexSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "账号同步超时，请检查本机同步任务是否已安装并运行。"])
            }
            try await Task.sleep(for: .milliseconds(500))
        } while !Task.isCancelled
        try Task.checkCancellation()
        if let usage = credits?.usage { return (usage, credits) }
        let logged = try await Task.detached(priority: .utility) { try CodexUsageReader.latest(in: url) }.value
        return (logged, credits)
    }
}
