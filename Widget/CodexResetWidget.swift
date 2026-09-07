import SwiftUI
import WidgetKit

struct ResetEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot
    let personal: PersonalUsage
}

struct ResetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ResetEntry {
        ResetEntry(date: .now, snapshot: Snapshot(), personal: PersonalUsage())
    }
    func getSnapshot(in context: Context, completion: @escaping (ResetEntry) -> Void) {
        completion(ResetEntry(date: .now, snapshot: SharedStorage.snapshot, personal: SharedStorage.personal))
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ResetEntry>) -> Void) {
        Task {
            let snapshot = await ResetAPI().refresh(previous: SharedStorage.snapshot)
            // The app owns the disk cache; the extension fetches its own fresh timeline.
            let personal = SharedStorage.personal
            let now = Date.now
            var entries = [ResetEntry(date: now, snapshot: snapshot, personal: personal)]
            let refreshAt = now.addingTimeInterval(900)
            if personal.isConfigured && personal.resetAt > now && personal.resetAt < refreshAt {
                entries.append(ResetEntry(date: personal.resetAt, snapshot: snapshot, personal: personal))
            }
            completion(Timeline(entries: entries, policy: .after(refreshAt)))
        }
    }
}

struct ResetWidgetView: View {
    let entry: ResetEntry
    @Environment(\.widgetFamily) private var family

    private var extraLarge: Bool { family == .systemExtraLarge }
    private var posts: [Post] { Array((entry.snapshot.feed?.tweets ?? []).sorted { $0.at > $1.at }.prefix(extraLarge ? 3 : 1)) }
    private var history: [ResetEvent] {
        Array((entry.snapshot.history?.events ?? []).filter { $0.type == "reset" && $0.source == "archive" }
            .sorted { ($0.announced_at ?? .distantPast) > ($1.announced_at ?? .distantPast) }.prefix(extraLarge ? 3 : 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Codex Reset", systemImage: "arrow.clockwise.circle.fill").font(.headline)
                Spacer(minLength: 0)
                if entry.snapshot.isStale(at: entry.date) { Image(systemName: "wifi.exclamationmark").foregroundStyle(.orange) }
            }
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.snapshot.forecast?.probabilities.rounded_24h.map { "\($0)%" } ?? "—")
                        .font(.system(size: 32, weight: .semibold, design: .rounded)).foregroundStyle(.teal)
                    Text("24h 重置概率").font(.caption).foregroundStyle(.secondary)
                    Text("48h · \(entry.snapshot.forecast?.probabilities.rounded_48h.map { "\($0)%" } ?? "—")")
                        .font(.caption)
                }
                Divider().frame(height: 78)
                VStack(alignment: .leading, spacing: 5) {
                    if entry.personal.isConfigured {
                        Text("剩余 \(Int(entry.personal.remainingPercent))%").font(.title3.bold())
                        GeometryReader { geometry in
                            Capsule().fill(.quaternary)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(.teal)
                                        .frame(width: geometry.size.width * entry.personal.remainingPercent / 100)
                                }
                        }
                        .frame(height: 5)
                        .accessibilityLabel("剩余 \(Int(entry.personal.remainingPercent))%")
                        if entry.personal.needsUpdate(at: entry.date) {
                            Text("已到期，请更新记录").foregroundStyle(.orange)
                        } else {
                            Text("重置 \(entry.personal.resetAt.formatted(.dateTime.month().day().hour().minute()))").monospacedDigit()
                        }
                        HStack(spacing: 4) {
                            Text(entry.personal.sourceLabel)
                            if entry.personal.isOld(at: entry.date) { Text("待更新").foregroundStyle(.orange) }
                        }.foregroundStyle(.secondary)
                        if let date = entry.personal.recordedAt {
                            Text("记录 \(date.formatted(.dateTime.month().day().hour().minute()))").foregroundStyle(.secondary)
                        }
                    } else {
                        Text("连接本机 Codex").font(.subheadline.bold())
                        Text("点击小组件，读取本地用量记录").foregroundStyle(.secondary)
                    }
                }.font(.caption).frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            if extraLarge {
                HStack(alignment: .top, spacing: 22) {
                    announcements.frame(maxWidth: .infinity, alignment: .topLeading)
                    historyList.frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                announcements
                historyList
            }
            Spacer(minLength: 0)
            Text(entry.snapshot.isStale(at: entry.date) ? "缓存 / 待更新 · 点击查看" : "实验预测 · codex-reset.com")
                .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "codexreset://open"))
    }

    private var announcements: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("最新公告").font(.caption.bold()).foregroundStyle(.secondary)
            if posts.isEmpty { Text("等待公告数据").font(.caption).foregroundStyle(.secondary) }
            ForEach(posts) { post in
                VStack(alignment: .leading, spacing: 3) {
                    if extraLarge { Text(post.at, format: .dateTime.month().day().hour().minute()).font(.caption2).foregroundStyle(.secondary) }
                    Text(post.text).font(.caption).lineLimit(2)
                }
            }
        }
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("站点核验的重置记录").font(.caption.bold()).foregroundStyle(.secondary)
            if history.isEmpty { Text("等待历史数据").font(.caption).foregroundStyle(.secondary) }
            ForEach(history) { event in
                VStack(alignment: .leading, spacing: 3) {
                    if let date = event.announced_at { Text(date, format: .dateTime.month().day()).font(.caption2).foregroundStyle(.secondary) }
                    Text(event.summary).font(.caption).lineLimit(2)
                }
            }
        }
    }
}

@main
struct CodexResetWidget: Widget {
    let kind = "CodexResetWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ResetProvider()) { entry in
            ResetWidgetView(entry: entry)
        }
        .configurationDisplayName("Codex Reset")
        .description("查看重置概率、最新公告、历史记录与个人用量。")
        .supportedFamilies([.systemLarge, .systemExtraLarge])
    }
}
