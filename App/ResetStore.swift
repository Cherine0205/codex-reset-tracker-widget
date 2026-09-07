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

    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        resetCredits = SharedStorage.resetCredits
        defer { refreshing = false }
        snapshot = await ResetAPI().refresh(previous: snapshot)
        do {
            try SharedStorage.save(snapshot, name: "snapshot.json")
            storageError = nil
        } catch { storageError = "无法保存共享数据，请检查签名和 App Group 配置。" }
        await refreshCodex()
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

    func refreshCodex() async {
        guard codexConnected else { return }
        do {
            let local = try await CodexConnection.read()
            guard codexConnected else { return }
            if let credits = local.credits {
                do {
                    try SharedStorage.save(credits, name: "reset-credits.json")
                    resetCredits = credits
                } catch { storageError = "重置券缓存保存失败" }
            }
            if let usage = local.usage {
                savePersonal(usage)
                codexError = nil
            } else { codexError = "最近 14 天未找到 Codex 周用量记录。使用 Codex 后再刷新。" }
        } catch {
            if codexConnected { codexError = "读取失败，请重新连接 Codex 文件夹。" }
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
