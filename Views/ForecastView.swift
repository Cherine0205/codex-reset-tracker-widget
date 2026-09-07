import SwiftUI

struct ForecastView: View {
    let snapshot: Snapshot
    var body: some View {
        ResetCard {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("重置预测").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "sparkles").foregroundStyle(.secondary)
                }
                HStack(spacing: 24) {
                    probability("未来 24 小时", value: snapshot.forecast?.probabilities.rounded_24h)
                    probability("未来 48 小时", value: snapshot.forecast?.probabilities.rounded_48h)
                }.padding(.vertical, 5)
                Divider().opacity(0.5)
                VStack(alignment: .leading, spacing: 6) {
                    SectionCaption(title: "最近一次全局重置")
                    if let date = snapshot.forecast?.last_reset_at {
                        Text(date, format: .dateTime.month().day().hour().minute())
                            .font(.system(size: 13, weight: .medium)).monospacedDigit()
                    } else { Text("—").foregroundStyle(.secondary) }
                }
                Label("实验预测 · \(snapshot.forecast?.confidence == "low" ? "低置信度" : snapshot.forecast?.confidence ?? "待更新")", systemImage: "info.circle")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }.frame(height: 234, alignment: .topLeading)
        }
    }
    private func probability(_ title: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value.map(String.init) ?? "—").font(.system(size: 42, weight: .medium, design: .rounded))
                if value != nil { Text("%").font(.system(size: 19)).foregroundStyle(.tertiary) }
            }.monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
