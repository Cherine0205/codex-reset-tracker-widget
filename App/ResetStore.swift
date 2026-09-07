import SwiftUI
import WidgetKit

@MainActor @Observable
final class ResetStore {
    var snapshot = SharedStorage.snapshot
    var personal = SharedStorage.personal
    var refreshing = false
    var storageError: String?

    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        snapshot = await ResetAPI().refresh(previous: snapshot)
        do {
            try SharedStorage.save(snapshot, name: "snapshot.json")
            storageError = nil
        } catch { storageError = "无法保存共享数据，请检查签名和 App Group 配置。" }
        WidgetCenter.shared.reloadAllTimelines()
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
