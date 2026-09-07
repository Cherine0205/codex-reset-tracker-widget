import SwiftUI

struct ForecastView: View {
    let snapshot: Snapshot
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Label("全局重置预测", systemImage: "sparkles").font(.headline)
                HStack(spacing: 30) {
                    probability("未来 24 小时", value: snapshot.forecast?.probabilities.rounded_24h)
                    probability("未来 48 小时", value: snapshot.forecast?.probabilities.rounded_48h)
                }
                Text("实验预测 · \(snapshot.forecast?.confidence == "low" ? "低置信度" : snapshot.forecast?.confidence ?? "待加载")")
                    .font(.caption).foregroundStyle(.orange)
                if let date = snapshot.forecast?.last_reset_at {
                    Text("最近全局重置\n\(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Text("概率由第三方站点计算，具体额度以账号为准。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 195, alignment: .topLeading).padding(10)
        }
    }
    private func probability(_ title: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value.map { "\($0)%" } ?? "—").font(.system(size: 36, weight: .semibold, design: .rounded)).foregroundStyle(.teal)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
}
