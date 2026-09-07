import SwiftUI

struct PersonalUsageView: View {
    let store: ResetStore
    @State private var editing = false
    @State private var draft = PersonalUsage()
    var body: some View {
        ResetCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("个人用量").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Menu {
                        if store.codexConnected {
                            Button("断开 Codex 连接", role: .destructive) { store.disconnectCodex() }
                        } else {
                            Button("连接本机 Codex…") { Task { await store.connectCodex() } }
                            Button("手动填写") { draft = store.personal; editing = true }
                        }
                    } label: { Image(systemName: "ellipsis").font(.system(size: 15)) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().foregroundStyle(.secondary)
                    .help("管理用量来源")
                }
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    HStack(spacing: 22) {
                        QuotaRing(percent: store.personal.isConfigured ? store.personal.remainingPercent : nil, size: 112)
                        VStack(alignment: .leading, spacing: 7) {
                            SectionCaption(title: "距离个人重置")
                            if store.personal.isConfigured {
                                Text(store.personal.needsUpdate(at: context.date) ? "等待新记录" : ResetPresentation.countdown(to: store.personal.resetAt, from: context.date))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded)).monospacedDigit()
                                    .lineLimit(1).minimumScaleFactor(0.8)
                                Text(store.personal.resetAt, format: .dateTime.month().day().hour().minute())
                                    .font(.system(size: 11)).foregroundStyle(.secondary)
                            } else {
                                Text("尚未连接").font(.system(size: 18, weight: .semibold))
                                Button("连接 Codex") { Task { await store.connectCodex() } }
                                    .font(.system(size: 11)).buttonStyle(.link)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(.vertical, 4)
                Spacer(minLength: 0)
                if let count = store.resetCredits.count(at: .now) {
                    HStack(spacing: 5) {
                        Label("重置券 \(count) 张", systemImage: "ticket").foregroundStyle(.blue)
                        Spacer()
                        if store.resetCredits.isStale(at: .now) {
                            Text("待更新").foregroundStyle(.orange)
                        } else if let expiry = store.resetCredits.nextExpiry(at: .now) {
                            Text("\(expiry.formatted(.dateTime.month().day())) 到期").foregroundStyle(.secondary)
                        }
                    }.font(.system(size: 10))
                }
                HStack(spacing: 5) {
                    Image(systemName: store.personal.isFromCodex ? "link" : "pencil")
                    Text(store.personal.sourceLabel)
                    Spacer(minLength: 2)
                    if let date = store.personal.recordedAt {
                        Text(date, format: .dateTime.hour().minute())
                    }
                }.font(.system(size: 10)).foregroundStyle(.secondary)
                if let error = store.codexError {
                    Text(error).font(.system(size: 10)).foregroundStyle(.orange).lineLimit(2)
                } else if store.personal.isOld() {
                    Text("记录已过期，使用 Codex 后更新").font(.system(size: 10)).foregroundStyle(.orange)
                }
            }.frame(height: 234, alignment: .topLeading)
        }
        .sheet(isPresented: $editing) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("记录周用量").font(.system(size: 23, weight: .bold))
                    Text("从 Codex /status 填写已用额度与重置时间。")
                        .font(.callout).foregroundStyle(.secondary)
                }
                HStack {
                    Slider(value: $draft.usedPercent, in: 0...100, step: 1)
                    Text("已用 \(Int(draft.usedPercent))%").monospacedDigit().frame(width: 90)
                }
                DatePicker("下次重置", selection: $draft.resetAt, displayedComponents: [.date, .hourAndMinute])
                Text("如果显示剩余 70%，填写已用 30%。时间按本机时区。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("清除", role: .destructive) { store.savePersonal(PersonalUsage()); editing = false }
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
            }.padding(30).frame(width: 450)
        }
    }
}
