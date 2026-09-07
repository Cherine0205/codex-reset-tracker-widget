import SwiftUI

@main
struct CodexResetApp: App {
    @State private var store = ResetStore()
    var body: some Scene {
        WindowGroup("Codex Reset", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 900, minHeight: 660)
                .onOpenURL { _ in NSApplication.shared.activate(ignoringOtherApps: true) }
                .task {
                    while !Task.isCancelled {
                        await store.refresh()
                        do { try await Task.sleep(for: .seconds(300)) } catch { break }
                    }
                }
        }
        .defaultSize(width: 1080, height: 820)
        .commands {
            CommandGroup(after: .newItem) {
                Button("刷新数据") { Task { await store.refresh() } }
                    .keyboardShortcut("r")
            }
        }
    }
}
