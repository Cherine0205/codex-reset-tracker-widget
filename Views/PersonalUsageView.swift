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
                    if store.codexConnected {
                        Button("断开") { store.disconnectCodex() }
                    } else {
                        Button("编辑") { draft = store.personal; editing = true }
                    }
                }
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    if store.personal.isConfigured {
                        Text("剩余 \(Int(store.personal.remainingPercent))%")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                        ProgressView(value: store.personal.remainingPercent, total: 100).tint(.teal)
                        if store.personal.needsUpdate(at: context.date) {
                            Text(store.personal.isFromCodex ? "已到重置时间，等待 Codex 新记录" : "已到重置时间，请核对并更新用量").foregroundStyle(.orange)
                        } else {
                            HStack {
                                Text("距离重置")
                                Text(store.personal.resetAt, style: .relative).monospacedDigit()
                            }
                            Text(store.personal.resetAt, format: .dateTime.month().day().hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("尚未设置").font(.title2)
                        Text("从 Codex /status 填写已用百分比和重置时间。")
                    }
                }
                .font(.callout)
                if !store.codexConnected {
                    Button("连接本机 Codex…") { Task { await store.connectCodex() } }
                }
                if let error = store.codexError { Text(error).font(.caption).foregroundStyle(.orange) }
                HStack {
                    Text(store.personal.sourceLabel)
                    if let date = store.personal.recordedAt {
                        Text(date, format: .dateTime.month().day().hour().minute())
                    }
                }.font(.caption).foregroundStyle(.secondary)
                if store.personal.isOld() {
                    Text("记录超过 30 分钟，使用 Codex 后再刷新").font(.caption).foregroundStyle(.orange)
                }
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
                        draft.source = nil
                        store.savePersonal(draft)
                        if store.storageError == nil { editing = false }
                    }.keyboardShortcut(.defaultAction)
                }
                if let error = store.storageError { Text(error).font(.caption).foregroundStyle(.red) }
            }.padding(24).frame(width: 460)
        }
    }
}
