import SwiftUI

private enum ResetPage: String, CaseIterable, Identifiable {
    case overview = "概览", feed = "公告", history = "重置历史"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .feed: "antenna.radiowaves.left.and.right"
        case .history: "clock.arrow.circlepath"
        }
    }
}

struct ContentView: View {
    @Bindable var store: ResetStore
    @State private var page: ResetPage? = .overview
    var body: some View {
        NavigationSplitView {
            List(ResetPage.allCases, selection: $page) { item in
                Label(item.rawValue, systemImage: item.symbol).tag(item)
            }
            .listStyle(.sidebar)
            .navigationTitle("Codex Reset")
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 7) {
                    Label(store.codexConnected ? "Codex 已连接" : "本机用量未连接", systemImage: store.codexConnected ? "checkmark.circle" : "link")
                        .font(.system(size: 11, weight: .medium))
                    Link("codex-reset.com ↗", destination: SourceLink.home)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 185, max: 220)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    pageHeader
                    if page == .feed {
                        FeedView(feed: store.snapshot.feed)
                    } else if page == .history {
                        HistoryView(history: store.snapshot.history)
                    } else {
                        HStack(alignment: .top, spacing: 18) {
                            PersonalUsageView(store: store)
                            ForecastView(snapshot: store.snapshot)
                        }
                        highlights
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.on.rectangle")
                            Text("在桌面添加 Codex Reset，随时查看用量。")
                            Spacer()
                            Text("大号 · 超大号")
                        }.font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                    if let error = store.storageError { notice(error) }
                    if store.snapshot.isStale() {
                        notice(store.snapshot.fetchedAt == nil ? "正在获取数据" : "连接暂不可用，显示最近缓存")
                    }
                }
                .padding(.horizontal, 30).padding(.top, 18).padding(.bottom, 28)
                .frame(maxWidth: 1120).frame(maxWidth: .infinity)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await store.refresh() } } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }.disabled(store.refreshing).help("刷新数据 ⌘R")
                }
            }
        }.tint(.blue)
    }
    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Date.now, format: .dateTime.month(.wide).day().weekday(.wide))
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(store.snapshot.isStale() ? Color.orange : Color.green).frame(width: 5, height: 5)
                    Text(store.refreshing ? "正在同步" : store.snapshot.fetchedAt.map { "\($0.formatted(date: .omitted, time: .shortened)) 更新" } ?? "等待同步")
                }
            }.font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            Text(page == .overview ? "用量与重置" : page?.rawValue ?? "用量与重置")
                .font(.system(size: 30, weight: .bold))
        }
    }
    private var highlights: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("值得关注").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("全部公告", systemImage: "arrow.right") { page = .feed }
                    .font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                let posts = Array(ResetPresentation.highlights(store.snapshot.feed).prefix(3))
                ForEach(posts) { post in
                    PostRow(post: post, compact: true).padding(.vertical, 17)
                    if post.id != posts.last?.id { Divider().opacity(0.55) }
                }
                if posts.isEmpty { Text("暂无新公告").font(.callout).foregroundStyle(.secondary).padding(24) }
            }
        }
    }
    private func notice(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange)
    }
}
