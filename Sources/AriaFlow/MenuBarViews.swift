import AppKit
import SwiftUI

struct AriaFlowMenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var updater: SoftwareUpdater
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
            updater.start()

            appDelegate.configure(store: store) {
                AppPresentation.showMainWindow(using: openWindow, store: store)
            }

            if store.settings.showMainWindowOnLaunch {
                AppPresentation.showMainWindow(using: openWindow, store: store)
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
        Button(L10n.tr("显示 AriaFlow")) {
            showMainWindow()
        }

        Button(L10n.tr("新建任务...")) {
            store.showAddTask = true
            showMainWindow()
        }
        .disabled(store.connectionState != .connected)

        Button(L10n.tr("设置...")) {
            AppPresentation.showSettings(using: openSettings, store: store)
        }

        Divider()

        Button(L10n.tr("继续全部")) {
            Task {
                await store.resumeAll()
            }
        }
        .disabled(store.connectionState != .connected || store.waitingCount == 0)

        Button(L10n.tr("暂停全部")) {
            Task {
                await store.pauseAll()
            }
        }
        .disabled(store.connectionState != .connected || store.activeCount == 0)

        Button(L10n.tr("保存会话")) {
            Task {
                await store.saveSession()
            }
        }
        .disabled(store.connectionState != .connected)

        Button(L10n.tr("清理结果")) {
            Task {
                await store.clearStoppedResults()
            }
        }
        .disabled(store.connectionState != .connected || (store.completeCount + store.failedCount) == 0)

        Divider()

        Text(L10n.tr("下载速度 \(store.downloadSpeedText)"))
        Text(L10n.tr("上传速度 \(store.uploadSpeedText)"))

        Divider()

        Button(L10n.tr("退出 AriaFlow")) {
            NSApp.terminate(nil)
        }
    }

    private func showMainWindow() {
        AppPresentation.showMainWindow(using: openWindow, store: store)
    }
}
