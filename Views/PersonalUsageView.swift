import SwiftUI

struct PersonalUsageView: View {
    let store: ResetStore
    @State private var editing = false
    @State private var draft = PersonalUsage()
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("个人周用量", systemImage: "gauge.with.dots.needle.50percent").font(.headline)
                    Spacer()
                    Button("编辑") { draft = store.personal; editing = true }
                }
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    if store.personal.isConfigured {
                        Text("剩余 \(Int(store.personal.remainingPercent))%")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                        ProgressView(value: store.personal.remainingPercent, total: 100).tint(.teal)
                        if store.personal.needsUpdate(at: context.date) {
                            Text("已到重置时间，请核对并更新用量").foregroundStyle(.orange)
                        } else {
                            HStack {
                                Text("距离重置")
                                Text(store.personal.resetAt, style: .relative).monospacedDigit()
                            }
                        }
                    } else {
                        Text("尚未设置").font(.title2)
                        Text("从 Codex /status 填写已用百分比和重置时间。")
                    }
                }
                .font(.callout)
                Text("手动记录 · 仅保存在此 Mac · 不自动读取账号")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 195, alignment: .topLeading).padding(10)
        }
        .sheet(isPresented: $editing) {
            VStack(alignment: .leading, spacing: 18) {
                Text("记录个人周用量").font(.title2.bold())
                Text("如果 /status 显示剩余 70%，请填写已用 30%。")
                    .foregroundStyle(.secondary)
                HStack {
                    Slider(value: $draft.usedPercent, in: 0...100, step: 1)
                    Text("已用 \(Int(draft.usedPercent))%").monospacedDigit().frame(width: 90)
                }
                DatePicker("下次重置", selection: $draft.resetAt, displayedComponents: [.date, .hourAndMinute])
                Text("时间使用本机时区：\(TimeZone.current.identifier)").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("清除记录", role: .destructive) { store.savePersonal(PersonalUsage()); editing = false }
                    Spacer()
                    Button("取消") { editing = false }.keyboardShortcut(.cancelAction)
                    Button("保存") {
                        draft.recordedAt = .now
                        store.savePersonal(draft)
                        if store.storageError == nil { editing = false }
                    }.keyboardShortcut(.defaultAction)
                }
                if let error = store.storageError { Text(error).font(.caption).foregroundStyle(.red) }
            }.padding(24).frame(width: 460)
        }
    }
}
