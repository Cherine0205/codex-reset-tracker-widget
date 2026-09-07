import SwiftUI

struct PostRow: View {
    let post: Post
    var compact = false
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: post.kind == "banked" ? "ticket" : post.kind == "boost" ? "bolt" : "waveform.path")
                .font(.system(size: 14, weight: .medium)).foregroundStyle(.blue)
                .frame(width: 34, height: 34)
                .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(ResetPresentation.category(post.kind)).font(.system(size: 12, weight: .semibold))
                    Text(post.at, format: .dateTime.month().day().hour().minute())
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    if let url = SourceLink.validated(post.url) {
                        Link(destination: url) { Image(systemName: "arrow.up.right").font(.system(size: 11)) }
                            .foregroundStyle(.secondary).help("在浏览器中阅读原文")
                    }
                }
                Text(post.text).font(.system(size: 13)).lineSpacing(4)
                    .foregroundStyle(.primary.opacity(0.85)).lineLimit(compact ? 2 : nil).textSelection(.enabled)
            }
        }
    }
}

struct FeedView: View {
    let feed: Feed?
    @State private var highlightsOnly = false
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Tibo · @thsottiaux").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Picker("公告范围", selection: $highlightsOnly) {
                    Text("全部").tag(false)
                    Text("重点").tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 150)
            }
            LazyVStack(spacing: 0) {
                let posts = highlightsOnly ? ResetPresentation.highlights(feed) : (feed?.tweets ?? []).sorted { $0.at > $1.at }
                ForEach(posts) { post in
                    PostRow(post: post).padding(.vertical, 20)
                    Divider().opacity(0.5)
                }
                if posts.isEmpty { ContentUnavailableView("暂无公告", systemImage: "antenna.radiowaves.left.and.right", description: Text("刷新后查看最新动态")) }
            }
        }
    }
}

struct HistoryView: View {
    let history: History?
    @State private var verifiedOnly = true
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("按时间排列的额度重置记录").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Picker("记录范围", selection: $verifiedOnly) {
                    Text("已核验").tag(true)
                    Text("全部").tag(false)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 150)
            }
            LazyVStack(alignment: .leading, spacing: 0) {
                let events = verifiedOnly ? ResetPresentation.verified(history) : (history?.events ?? []).filter { $0.type == "reset" }.sorted { ($0.announced_at ?? .distantPast) > ($1.announced_at ?? .distantPast) }
                ForEach(events) { event in
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            if let date = event.announced_at {
                                Text(date, format: .dateTime.month().day()).font(.system(size: 14, weight: .semibold))
                                Text(date, format: .dateTime.hour().minute()).font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                        }.frame(width: 68, alignment: .leading)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label(event.statusLabel, systemImage: event.source == "archive" ? "checkmark.seal" : "clock")
                                    .font(.system(size: 11)).foregroundStyle(event.source == "archive" ? Color.secondary : .orange)
                                Spacer()
                                if let url = SourceLink.validated(event.url) {
                                    Link(destination: url) { Image(systemName: "arrow.up.right").font(.system(size: 11)) }.foregroundStyle(.secondary)
                                }
                            }
                            Text(event.summary).font(.system(size: 13)).lineSpacing(4).textSelection(.enabled)
                            Divider().opacity(0.5).padding(.top, 12)
                        }
                    }.padding(.vertical, 16)
                }
                if events.isEmpty { ContentUnavailableView("暂无重置记录", systemImage: "clock.arrow.circlepath") }
            }
        }
    }
}
