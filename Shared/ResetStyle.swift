import SwiftUI

struct QuotaRing: View {
    let percent: Double?
    var size: CGFloat = 128
    private var tint: Color { (percent ?? 100) <= 15 ? .orange : .blue }
    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.10), lineWidth: size * 0.065)
            Circle().trim(from: 0, to: max(0, min(1, (percent ?? 0) / 100)))
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: size * 0.065, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(percent.map { "\(Int($0))" } ?? "—")
                        .font(.system(size: size * 0.31, weight: .semibold, design: .rounded))
                    if percent != nil { Text("%").font(.system(size: size * 0.13, weight: .medium)).foregroundStyle(.secondary) }
                }.monospacedDigit()
                Text("周额度剩余").font(.system(size: max(9, size * 0.075), weight: .medium)).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(percent.map { "周额度剩余 \(Int($0))%" } ?? "尚未连接个人用量")
    }
}

struct ResetCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.primary.opacity(0.06), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.025), radius: 12, y: 4)
    }
}

struct SectionCaption: View {
    let title: String
    var body: some View {
        Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
    }
}

enum ResetPresentation {
    static func countdown(to end: Date, from now: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(now)))
        let days = seconds / 86400
        let hours = seconds % 86400 / 3600
        if days > 0 { return "\(days)天 \(hours)小时" }
        if hours > 0 { return "\(hours)小时 \(seconds % 3600 / 60)分" }
        return seconds >= 60 ? "\(seconds / 60)分钟" : "即将重置"
    }
    static func highlights(_ feed: Feed?) -> [Post] {
        (feed?.tweets ?? []).filter { ["reset", "boost", "banked", "limits", "signal"].contains($0.kind) }.sorted { $0.at > $1.at }
    }
    static func verified(_ history: History?) -> [ResetEvent] {
        (history?.events ?? []).filter { $0.type == "reset" && $0.source == "archive" }
            .sorted { ($0.announced_at ?? .distantPast) > ($1.announced_at ?? .distantPast) }
    }
    static func category(_ kind: String) -> String {
        switch kind {
        case "reset": "额度重置"
        case "boost": "用量优化"
        case "banked": "重置券"
        case "limits": "额度动态"
        case "signal": "重置信号"
        case "candidate": "待核验"
        default: "社区动态"
        }
    }
}
