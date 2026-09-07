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
                    if family != .systemSmall {
                        Text("48h · \(entry.snapshot.forecast?.probabilities.rounded_48h.map { "\($0)%" } ?? "—")")
                            .font(.caption)
                    }
                }
                if family != .systemSmall {
                    Divider()
                    VStack(alignment: .leading, spacing: 5) {
                        if entry.personal.isConfigured {
                            Text("剩余 \(Int(entry.personal.remainingPercent))%").font(.title3.bold())
                            ProgressView(value: entry.personal.remainingPercent, total: 100).tint(.teal)
                            if entry.personal.needsUpdate(at: entry.date) {
                                Text("已到期，请更新记录").foregroundStyle(.orange)
                            } else {
                                Text(entry.personal.resetAt, style: .relative).monospacedDigit()
                            }
                            Text("个人周用量 · 手动记录").foregroundStyle(.secondary)
                        } else {
                            Text("设置个人用量").font(.subheadline.bold())
                            Text("点击小组件，填写 /status 数据").foregroundStyle(.secondary)
                        }
                    }.font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if family == .systemLarge {
                Divider()
                if let post = entry.snapshot.feed?.tweets.sorted(by: { $0.at > $1.at }).first {
                    Text("最新公告 · \(post.kind)").font(.caption.bold()).foregroundStyle(.secondary)
                    Text(post.text).font(.callout).lineLimit(3)
                }
                if let event = entry.snapshot.history?.events.filter({ $0.type == "reset" && $0.source == "archive" }).max(by: { ($0.announced_at ?? .distantPast) < ($1.announced_at ?? .distantPast) }) {
                    Text("最近站点核验记录").font(.caption.bold()).foregroundStyle(.secondary)
                    Text(event.summary).font(.caption).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Text(entry.snapshot.isStale(at: entry.date) ? "缓存 / 待更新 · 点击查看" : "实验预测 · codex-reset.com")
                .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "codexreset://open"))
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
