import SwiftUI

struct ContentView: View {
    @Bindable var store: ResetStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Codex Reset").font(.largeTitle.bold())
                        Text("重置动态 · 概率预测 · 个人用量").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Link("数据来源 ↗", destination: SourceLink.home)
                }
                HStack(alignment: .top, spacing: 16) {
                    ForecastView(snapshot: store.snapshot)
                    PersonalUsageView(store: store)
                }
                if let error = store.storageError { Text(error).foregroundStyle(.red) }
                if store.snapshot.isStale() {
                    Label(store.snapshot.fetchedAt == nil ? "等待完整数据；可用内容将先显示" : "数据可能已过期，正在显示最近可用记录", systemImage: "wifi.exclamationmark")
                        .font(.callout).foregroundStyle(.orange)
                }
                if !store.snapshot.errors.isEmpty {
                    Text(store.snapshot.errors.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                }
                TabView {
                    FeedView(feed: store.snapshot.feed)
                        .tabItem { Label("公告动态", systemImage: "antenna.radiowaves.left.and.right") }
                    HistoryView(history: store.snapshot.history)
                        .tabItem { Label("历史重置", systemImage: "clock.arrow.circlepath") }
                }
                .frame(height: 320)
                HStack {
                    Text("右键桌面 → 编辑小组件 → 搜索 Codex Reset")
                    Spacer()
                    if let date = store.snapshot.fetchedAt {
                        Text("同步 \(date.formatted(date: .omitted, time: .shortened))")
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .toolbar {
            Button { Task { await store.refresh() } } label: {
                Label(store.refreshing ? "更新中" : "刷新", systemImage: "arrow.clockwise")
            }.disabled(store.refreshing)
        }
    }
}
