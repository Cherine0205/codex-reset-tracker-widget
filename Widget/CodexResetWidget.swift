import SwiftUI
import WidgetKit

struct ResetEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot
    let personal: PersonalUsage
    var credits: ResetCredits = ResetCredits()
}

struct ResetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ResetEntry {
        ResetEntry(date: .now, snapshot: Snapshot(), personal: PersonalUsage())
    }
    func getSnapshot(in context: Context, completion: @escaping (ResetEntry) -> Void) {
        completion(ResetEntry(date: .now, snapshot: SharedStorage.snapshot, personal: SharedStorage.personal, credits: SharedStorage.resetCredits))
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ResetEntry>) -> Void) {
        Task {
            let snapshot = await ResetAPI().refresh(previous: SharedStorage.snapshot)
            // The app owns the disk cache; the extension fetches its own fresh timeline.
            let personal = SharedStorage.personal
            let credits = SharedStorage.resetCredits
            let now = Date.now
            var entries = [ResetEntry(date: now, snapshot: snapshot, personal: personal, credits: credits)]
            let refreshAt = now.addingTimeInterval(900)
            if personal.isConfigured && personal.resetAt > now && personal.resetAt < refreshAt {
                entries.append(ResetEntry(date: personal.resetAt, snapshot: snapshot, personal: personal, credits: credits))
            }
            if let expiry = credits.nextExpiry(at: now), expiry < refreshAt {
                entries.append(ResetEntry(date: expiry, snapshot: snapshot, personal: personal, credits: credits))
                entries.sort { $0.date < $1.date }
            }
            completion(Timeline(entries: entries, policy: .after(refreshAt)))
        }
    }
}

struct ResetWidgetView: View {
    let entry: ResetEntry
    @Environment(\.widgetFamily) private var family
    private var extraLarge: Bool { family == .systemExtraLarge }
    private var posts: [Post] { Array(ResetPresentation.highlights(entry.snapshot.feed).prefix(extraLarge ? 3 : 2)) }
    private var events: [ResetEvent] { Array(ResetPresentation.verified(entry.snapshot.history).prefix(extraLarge ? 3 : 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            header
            HStack(alignment: .top, spacing: 12) {
                usageMetric
                countdownMetric
                creditMetric
                if extraLarge {
                    forecastMetric(entry.snapshot.forecast?.probabilities.rounded_24h, label: "24h 重置概率")
                    forecastMetric(entry.snapshot.forecast?.probabilities.rounded_48h, label: "48h 重置概率")
                }
            }
            if !extraLarge { forecastStrip }
            Divider().opacity(0.5)
            if extraLarge {
                HStack(alignment: .top, spacing: 20) {
                    news.frame(maxWidth: .infinity, alignment: .leading)
                    Rectangle().fill(.primary.opacity(0.06)).frame(width: 0.5)
                    history.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: .infinity, alignment: .top)
            } else {
                news
                Divider().opacity(0.4)
                history
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .containerBackground(for: .widget) {
            Rectangle().fill(.background).overlay {
                LinearGradient(colors: [.blue.opacity(0.06), .clear, .primary.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .widgetURL(URL(string: "codexreset://open"))
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.hexagongrid.fill").font(.system(size: 12))
            Text("Codex Reset").font(.system(size: 12, weight: .semibold))
            Spacer()
            if let recorded = entry.personal.recordedAt {
                Text("\(recorded.formatted(date: .omitted, time: .shortened)) 记录")
                    .font(.system(size: 9)).foregroundStyle(entry.personal.isOld(at: entry.date) ? Color.orange : .secondary)
            }
            Circle().fill(entry.snapshot.isStale(at: entry.date) ? Color.orange : Color.green).frame(width: 4, height: 4)
            Link(destination: URL(string: "codexreset://refresh")!) {
                Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary).frame(width: 22, height: 22)
                    .background(.primary.opacity(0.05), in: Circle())
            }.buttonStyle(.plain).accessibilityLabel("同步 Codex 账号和小组件数据")
                .help("打开主应用并同步最新账号用量、重置券与站点数据")
        }
    }

    private var usageMetric: some View {
        VStack(alignment: .leading, spacing: 4) {
            caption("周额度剩余")
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(entry.personal.isConfigured ? "\(Int(entry.personal.remainingPercent))" : "—")
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                if entry.personal.isConfigured { Text("%").font(.system(size: 12)).foregroundStyle(.secondary) }
            }.monospacedDigit()
            GeometryReader { geometry in
                Capsule().fill(.blue.opacity(0.1)).overlay(alignment: .leading) {
                    Capsule().fill(.blue).frame(width: geometry.size.width * (entry.personal.isConfigured ? entry.personal.remainingPercent / 100 : 0))
                }
            }.frame(height: 3).padding(.trailing, 12)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var countdownMetric: some View {
        VStack(alignment: .leading, spacing: 7) {
            caption("距离重置")
            Text(entry.personal.isConfigured ? entry.personal.needsUpdate(at: entry.date) ? "待更新" : ResetPresentation.countdown(to: entry.personal.resetAt, from: entry.date) : "未连接")
                .font(.system(size: 15, weight: .medium, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
            if entry.personal.isConfigured {
                Text(entry.personal.resetAt, format: .dateTime.month().day().hour().minute())
                    .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var creditMetric: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("重置券", systemImage: "ticket").font(.system(size: 10)).foregroundStyle(.secondary)
            Text(entry.credits.count(at: entry.date).map { "\($0) 张" } ?? "未同步")
                .font(.system(size: 21, weight: .medium, design: .rounded)).foregroundStyle(.blue)
            if entry.credits.isStale(at: entry.date), entry.credits.fetchedAt != nil {
                Text("记录待更新").font(.system(size: 9)).foregroundStyle(.orange)
            } else if let expiry = entry.credits.nextExpiry(at: entry.date) {
                Text("\(expiry.formatted(.dateTime.month().day())) 到期")
                    .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .help(entry.credits.nextExpiry(at: entry.date).map { "最近到期：\($0.formatted())" } ?? "暂无到期明细")
    }

    private var forecastStrip: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles").font(.system(size: 10)).foregroundStyle(.secondary)
            Text("重置预测").font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            inlineProbability(entry.snapshot.forecast?.probabilities.rounded_24h, label: "24h")
            Text("·").foregroundStyle(.tertiary)
            inlineProbability(entry.snapshot.forecast?.probabilities.rounded_48h, label: "48h")
        }.padding(.horizontal, 9).padding(.vertical, 6)
            .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
    }

    private func inlineProbability(_ value: Int?, label: String) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(.secondary)
            Text(value.map { "\($0)%" } ?? "—").fontWeight(.semibold).monospacedDigit()
        }.font(.system(size: 11))
    }

    private func forecastMetric(_ value: Int?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            caption(label)
            Text(value.map { "\($0)%" } ?? "—").font(.system(size: 25, weight: .medium, design: .rounded)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var news: some View {
        VStack(alignment: .leading, spacing: 9) {
            if extraLarge { caption("最新动态") }
            ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(ResetPresentation.category(post.kind)).fontWeight(.medium)
                        Spacer()
                        Text(post.at, format: .dateTime.month().day())
                    }.font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(post.text.split(whereSeparator: \.isWhitespace).joined(separator: " "))
                        .font(.system(size: 11)).lineSpacing(1).lineLimit(extraLarge ? 3 : index == 0 ? 3 : 2)
                }
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 9) {
            if extraLarge { caption("已核验的重置") }
            ForEach(events) { event in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Label("已核验重置", systemImage: "checkmark.seal")
                        Spacer()
                        if let date = event.announced_at { Text(date, format: .dateTime.month().day()) }
                    }.font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(event.summary).font(.system(size: 11)).lineSpacing(1).lineLimit(extraLarge ? 3 : 2)
                }
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.system(size: 10)).foregroundStyle(.secondary)
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
        .contentMarginsDisabled()
    }
}
