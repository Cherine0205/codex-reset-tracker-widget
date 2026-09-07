import SwiftUI

struct FeedView: View {
    let feed: Feed?
    var body: some View {
        List {
            if let feed {
                ForEach(feed.tweets.sorted { $0.at > $1.at }.prefix(40)) { post in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(post.kind.uppercased()).font(.caption.bold()).foregroundStyle(.teal)
                            Text(post.at, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            if let url = SourceLink.validated(post.url) { Link("原文 ↗", destination: url).font(.caption) }
                        }
                        Text(post.text).font(.callout).textSelection(.enabled)
                    }.padding(.vertical, 6)
                }
            } else { Text("公告暂不可用，点击刷新重试。").foregroundStyle(.secondary) }
        }
    }
}

struct HistoryView: View {
    let history: History?
    var body: some View {
        List {
            if let history {
                ForEach(history.events.filter { $0.type == "reset" }.sorted { ($0.announced_at ?? .distantPast) > ($1.announced_at ?? .distantPast) }) { event in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(event.statusLabel).foregroundStyle(event.source == "archive" ? .teal : .orange)
                            if let date = event.announced_at { Text(date, format: .dateTime.year().month().day().hour().minute()) }
                            Spacer()
                            if let url = SourceLink.validated(event.url) { Link("来源 ↗", destination: url) }
                        }.font(.caption)
                        Text(event.summary).font(.callout).textSelection(.enabled)
                    }.padding(.vertical, 6)
                }
            } else { Text("历史记录暂不可用。").foregroundStyle(.secondary) }
        }
    }
}
