import AppKit
import SwiftUI

struct AriaFlowMenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: AppStore
    @State private var didBootstrap = false

    let appDelegate: AriaFlowAppDelegate

    var body: some View {
        Group {
            if store.settings.showSpeedInMenuBar {
                Text("↓ \(store.downloadSpeedText)")
            } else {
                Image(systemName: "arrow.down.circle")
                    .accessibilityLabel("AriaFlow")
            }
        }
        .task {
            guard !didBootstrap else { return }
            didBootstrap = true

            appDelegate.configure(store: store) {
                AppPresentation.showMainWindow(using: openWindow)
            }

            if store.settings.showMainWindowOnLaunch {
                AppPresentation.showMainWindow(using: openWindow)
            } else {
                AppPresentation.updateActivationPolicy(store: store)
            }

            await store.startAutomaticConnectionIfNeeded()
        }
    }
}

struct AriaFlowMenuBarView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Button("显示 AriaFlow") {
            showMainWindow()
        }

        Button("新建任务...") {
            store.showAddTask = true
            showMainWindow()
        }
        .disabled(store.connectionState != .connected)

        Button("设置...") {
            AppPresentation.showSettings(using: openSettings)
        }

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

        Button("保存会话") {
            Task {
                await store.saveSession()
            }
        }
        .disabled(store.connectionState != .connected)

        Button("清理结果") {
            Task {
                await store.clearStoppedResults()
            }
        }
        .disabled(store.connectionState != .connected || (store.completeCount + store.failedCount) == 0)

        Divider()

        Text("下载速度 \(store.downloadSpeedText)")
        Text("上传速度 \(store.uploadSpeedText)")

        Divider()

        Button("退出 AriaFlow") {
            NSApp.terminate(nil)
        }
    }

    private func showMainWindow() {
        AppPresentation.showMainWindow(using: openWindow)
    }
}
