import SwiftUI
import WidgetKit

@MainActor @Observable
final class ResetStore {
    var snapshot = SharedStorage.snapshot
    var personal = SharedStorage.personal
    var refreshing = false
    var storageError: String?
    var codexConnected = CodexConnection.isConnected
    var codexError: String?
    var resetCredits = SharedStorage.resetCredits
    private var pendingAccountRefresh = false

    func refresh(forceAccount: Bool = true) async {
        guard !refreshing else {
            if forceAccount { pendingAccountRefresh = true }
            return
        }
        refreshing = true
        resetCredits = SharedStorage.resetCredits
        defer {
            refreshing = false
            if pendingAccountRefresh {
                pendingAccountRefresh = false
                Task { await self.refresh() }
            }
        }
        async let remote = ResetAPI().refresh(previous: snapshot)
        await refreshCodex(requestNew: forceAccount)
        snapshot = await remote
        do {
            try SharedStorage.save(snapshot, name: "snapshot.json")
            storageError = nil
        } catch { storageError = "无法保存共享数据，请检查签名和 App Group 配置。" }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func connectCodex() async {
        do {
            if try CodexConnection.chooseFolder() {
                codexConnected = true
                await refreshCodex()
            }
        } catch { codexError = error.localizedDescription }
    }

    func disconnectCodex() {
        CodexConnection.disconnect()
        codexConnected = false
        codexError = nil
        savePersonal(PersonalUsage())
    }

    func refreshCodex(requestNew: Bool = false) async {
        guard codexConnected else { return }
        do {
            var requestedAt: Date?
            if requestNew {
                guard let marker = SharedStorage.directory?.appendingPathComponent("sync-request.json"),
                      FileManager.default.fileExists(atPath: marker.path) else {
                    throw NSError(domain: "CodexSync", code: 2, userInfo: [NSLocalizedDescriptionKey: "请先运行 script/install_credit_sync.py 安装账号同步任务。"])
                }
                requestedAt = .now
                // Preserve the watched inode so launchd sees an explicit write event.
                try JSONEncoder().encode(UUID().uuidString).write(to: marker)
            }
            let local = try await CodexConnection.read(requestedAfter: requestedAt)
            guard codexConnected else { return }
            if let credits = local.credits {
                do {
                    try SharedStorage.save(credits, name: "reset-credits.json")
                    resetCredits = credits
                } catch { storageError = "重置券缓存保存失败" }
            }
            if let usage = local.usage {
                savePersonal(usage)
                codexError = local.credits?.error
            } else { codexError = "最近 14 天未找到 Codex 周用量记录。使用 Codex 后再刷新。" }
        } catch {
            if codexConnected { codexError = error.localizedDescription }
        }
    }

    func savePersonal(_ value: PersonalUsage) {
        do {
            try SharedStorage.save(value, name: "personal.json")
            personal = value
            storageError = nil
            WidgetCenter.shared.reloadAllTimelines()
        } catch { storageError = "保存失败，小组件尚未同步。请检查 App Group 配置。" }
    }
}
