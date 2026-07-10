import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct AriaFlowApp: App {
    init() {
        _ = SmokeDownloadRunner.runIfRequested()
    }

    @NSApplicationDelegateAdaptor(AriaFlowAppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()

    var body: some Scene {
        Window("AriaFlow", id: "main") {
            MainWindowView()
                .environmentObject(store)
                .frame(minWidth: 720, minHeight: 420)
                .onAppear {
                    AppPresentation.mainWindowDidAppear()
                }
                .onDisappear {
                    AppPresentation.mainWindowDidDisappear(store: store)
                }
        }
        .defaultSize(width: 720, height: 420)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建任务...") {
                    store.showAddTask = true
                }
                .disabled(store.connectionState != .connected)
                .keyboardShortcut("n")

                Button("打开 Torrent...") {
                    chooseTorrentFile(store: store)
                }
                .disabled(store.connectionState != .connected)
                .keyboardShortcut("o")
            }

            CommandMenu("任务") {
                Button("刷新任务") {
                    Task {
                        await store.refreshTasksFromEngine()
                    }
                }
                .disabled(store.connectionState != .connected)
                .keyboardShortcut("r")

                Divider()

                Button("继续") {
                    Task {
                        await store.resumeSelected()
                    }
                }
                .disabled(store.connectionState != .connected || !store.canResumeSelected)

                Button("暂停") {
                    Task {
                        await store.pauseSelected()
                    }
                }
                .disabled(store.connectionState != .connected || !store.canPauseSelected)

                Divider()

                Button("继续全部") {
                    Task {
                        await store.resumeAll()
                    }
                }
                .disabled(store.connectionState != .connected || store.waitingCount == 0)

                Button("暂停全部") {
                    Task {
                        await store.pauseAll()
                    }
                }
                .disabled(store.connectionState != .connected || store.activeCount == 0)

                Divider()

                Button("保存会话") {
                    Task {
                        await store.saveSession()
                    }
                }
                .disabled(store.connectionState != .connected)

                Button("清理完成和失败结果") {
                    Task {
                        await store.clearStoppedResults()
                    }
                }
                .disabled(store.connectionState != .connected || (store.completeCount + store.failedCount) == 0)

                Divider()

                Button("删除...") {
                    store.showDeleteConfirmation = true
                }
                .disabled(store.connectionState != .connected || store.selectedTask == nil)
            }
        }

        MenuBarExtra {
            AriaFlowMenuBarView()
                .environmentObject(store)
        } label: {
            AriaFlowMenuBarLabel(appDelegate: appDelegate)
                .environmentObject(store)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsWindowView()
                .environmentObject(store)
                .frame(width: 400, height: 360)
                .onAppear {
                    AppPresentation.settingsDidAppear()
                }
                .onDisappear {
                    AppPresentation.settingsDidDisappear(store: store)
                }
        }
    }
}

@MainActor
private func chooseTorrentFile(store: AppStore) {
    let panel = NSOpenPanel()
    if let torrentType = UTType(filenameExtension: "torrent") {
        panel.allowedContentTypes = [torrentType]
    }
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = false

    if panel.runModal() == .OK, let url = panel.url {
        Task {
            await store.addTorrentTask(fileURL: url, splitCount: store.settings.splitCount)
        }
    }
}
