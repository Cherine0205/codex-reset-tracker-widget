import SwiftUI
import WidgetKit
import AppIntents

struct RefreshResetWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "刷新 Codex Reset"
    static let description = IntentDescription("刷新公告、历史和预测，并读取最近同步的个人用量。")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        // WidgetKit requests a new timeline after a button intent completes.
        // The provider fetches all three endpoints before supplying that timeline.
        WidgetCenter.shared.reloadTimelines(ofKind: "CodexResetWidget")
        return .result()
    }
}

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
    private var posts: [Post] { Array(ResetPresentation.highlights(entry.snapshot.feed).prefix(2)) }
    private var events: [ResetEvent] { Array(ResetPresentation.verified(entry.snapshot.history).prefix(2)) }
    private var percent: Double? { entry.personal.isConfigured ? entry.personal.remainingPercent : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "circle.hexagongrid.fill").font(.system(size: 13, weight: .medium))
                Text("Codex Reset").font(.system(size: 12, weight: .medium))
                Spacer()
                Circle().fill(entry.snapshot.isStale(at: entry.date) ? Color.orange : Color.green).frame(width: 5, height: 5)
                Button(intent: RefreshResetWidgetIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(.primary.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("刷新公告、历史和预测")
                .help("刷新公告、历史与预测；个人用量使用最近同步记录")
            }
            if extraLarge {
                HStack(alignment: .top, spacing: 16) {
                    expandedMetrics.frame(width: 250)
                    Rectangle().fill(.primary.opacity(0.07)).frame(width: 0.5)
                    expandedNews.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: .infinity)
            } else {
                compactContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .containerBackground(for: .widget) {
            Rectangle().fill(.background)
                .overlay {
                    LinearGradient(colors: [.blue.opacity(0.07), .clear, .primary.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
        }
        .widgetURL(URL(string: "codexreset://open"))
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                QuotaRing(percent: percent, size: 88)
                resetCountdown
            }
            probabilities
            Divider().opacity(0.45)
            if let post = posts.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ResetPresentation.category(post.kind)).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    Text(post.text.split(whereSeparator: \.isWhitespace).joined(separator: " ")).font(.system(size: 11, weight: .regular)).lineSpacing(2).lineLimit(4)
                }
            }
            if let event = events.first, let date = event.announced_at {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal").font(.system(size: 10))
                        Text("最近核验重置")
                        Spacer()
                        Text(date, format: .dateTime.month().day())
                    }.font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(event.summary).font(.system(size: 11)).lineSpacing(2).lineLimit(2)
                }
            }
        }
    }

    private var expandedMetrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                QuotaRing(percent: percent, size: 108)
                resetCountdown
            }
            probabilities.padding(.vertical, 4)
            if let date = entry.snapshot.forecast?.last_reset_at {
                VStack(alignment: .leading, spacing: 5) {
                    SectionCaption(title: "最近一次全局重置")
                    Text(date, format: .dateTime.month().day().hour().minute())
                        .font(.system(size: 12, weight: .medium))
                }
            }
        }
    }

    private var resetCountdown: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("距离个人重置").font(.system(size: 10)).foregroundStyle(.secondary)
            Text(entry.personal.isConfigured ? entry.personal.needsUpdate(at: entry.date) ? "等待更新" : ResetPresentation.countdown(to: entry.personal.resetAt, from: entry.date) : "连接 Codex")
                .font(.system(size: extraLarge ? 15 : 17, weight: .medium, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.75)
            if entry.personal.isConfigured {
                Text(entry.personal.resetAt, format: .dateTime.month().day().hour().minute())
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            if let recorded = entry.personal.recordedAt {
                Text("\(recorded.formatted(date: .omitted, time: .shortened)) 记录\(entry.personal.isOld(at: entry.date) ? " · 待更新" : "")")
                    .font(.system(size: 9)).foregroundStyle(entry.personal.isOld(at: entry.date) ? Color.orange : .secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "ticket")
                    Text("重置券")
                    Text(entry.credits.count(at: entry.date).map { "\($0) 张" } ?? "未同步").fontWeight(.semibold)
                }.font(.system(size: 11)).foregroundStyle(.blue)
                if entry.credits.isStale(at: entry.date), entry.credits.fetchedAt != nil {
                    Text("记录待更新").foregroundStyle(.orange)
                } else if let expiry = entry.credits.nextExpiry(at: entry.date) {
                    Text("\(expiry.formatted(.dateTime.month().day().hour().minute())) 到期").foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 9))
            .padding(.top, 3)
            .help(entry.credits.fetchedAt.map { "重置券同步于 \($0.formatted())" } ?? "尚未读取重置券")
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var probabilities: some View {
        HStack(spacing: 0) {
            probability(entry.snapshot.forecast?.probabilities.rounded_24h, label: "24h 内重置")
            Rectangle().fill(.primary.opacity(0.06)).frame(width: 0.5, height: 28).padding(.horizontal, 18)
            probability(entry.snapshot.forecast?.probabilities.rounded_48h, label: "48h 内重置")
        }
    }

    private func probability(_ value: Int?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value.map(String.init) ?? "—").font(.system(size: 25, weight: .medium, design: .rounded))
                if value != nil { Text("%").font(.system(size: 12)).foregroundStyle(.secondary) }
            }.monospacedDigit()
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var expandedNews: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionCaption(title: "最新动态")
            ForEach(posts) { post in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(ResetPresentation.category(post.kind)).fontWeight(.medium)
                        Spacer()
                        Text(post.at, format: .dateTime.month().day())
                    }.font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(post.text.split(whereSeparator: \.isWhitespace).joined(separator: " ")).font(.system(size: 12, weight: .regular)).lineSpacing(2).lineLimit(3)
                }
            }
            Divider().opacity(0.45)
            SectionCaption(title: "已核验的重置")
            ForEach(events) { event in
                HStack(alignment: .top, spacing: 12) {
                    if let date = event.announced_at {
                        Text(date, format: .dateTime.month().day()).font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary).frame(width: 45, alignment: .leading)
                    }
                    Text(event.summary).font(.system(size: 11, weight: .regular)).lineSpacing(2).lineLimit(3)
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
        .contentMarginsDisabled()
    }
}
