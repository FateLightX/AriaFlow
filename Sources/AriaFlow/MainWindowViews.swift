import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MainWindowView: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var store: AppStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 170, ideal: 180, max: 220)
        } detail: {
            ContentAreaView()
                .navigationSplitViewColumnWidth(min: 420, ideal: 620)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.showAddTask = true
                } label: {
                    Label(L10n.tr("添加"), systemImage: "plus")
                }
                .disabled(store.connectionState != .connected)
                .help(L10n.tr("添加任务"))

                Button {
                    Task {
                        await store.resumeSelected()
                    }
                } label: {
                    Label(L10n.tr("继续"), systemImage: "play.fill")
                }
                .disabled(store.connectionState != .connected || !store.canResumeSelected)
                .help(L10n.tr("继续选中的任务"))

                Button {
                    Task {
                        await store.pauseSelected()
                    }
                } label: {
                    Label(L10n.tr("暂停"), systemImage: "pause.fill")
                }
                .disabled(store.connectionState != .connected || !store.canPauseSelected)
                .help(L10n.tr("暂停选中的任务"))

                Button {
                    store.showDeleteConfirmation = true
                } label: {
                    Label(L10n.tr("删除"), systemImage: "trash")
                }
                .disabled(store.connectionState != .connected || store.selectedTask == nil)
                .help(L10n.tr("删除选中的任务"))

                Button {
                    Task {
                        await store.refreshTasksFromEngine()
                    }
                } label: {
                    Label(L10n.tr("刷新"), systemImage: "arrow.clockwise")
                }
                .disabled(store.connectionState != .connected)
                .help(L10n.tr("刷新任务列表"))
            }

            ToolbarItemGroup(placement: .automatic) {
                Button {
                    openSettings()
                } label: {
                    Label(L10n.tr("设置"), systemImage: "gearshape")
                }
                .help(L10n.tr("打开设置"))
            }
        }
        .sheet(isPresented: $store.showAddTask) {
            AddTaskSheet()
                .environmentObject(store)
                .frame(width: 560, height: 460)
        }
        .sheet(isPresented: $store.showFileSelection) {
            FileSelectionSheet()
                .environmentObject(store)
                .frame(width: 560, height: 420)
        }
        .sheet(isPresented: $store.showDeleteConfirmation) {
            DeleteConfirmationSheet()
                .environmentObject(store)
                .frame(width: 440)
        }
    }

}

struct SidebarView: View {
    @EnvironmentObject private var store: AppStore

    private let taskFilters: [TaskFilter] = [.all, .active, .waiting, .complete, .failed]

    private var selection: Binding<TaskFilter?> {
        Binding {
            store.selectedFilter
        } set: { filter in
            guard let filter else { return }
            store.selectFilter(filter)
        }
    }

    var body: some View {
        List(selection: selection) {
            Section(L10n.tr("下载任务")) {
                ForEach(taskFilters) { filter in
                    SidebarFilterRow(filter: filter)
                        .tag(filter)
                }
            }

            Section(L10n.tr("资料库")) {
                SidebarFilterRow(filter: .history)
                    .tag(TaskFilter.history)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("AriaFlow")
    }
}

struct SidebarFilterRow: View {
    @EnvironmentObject private var store: AppStore
    let filter: TaskFilter

    var body: some View {
        HStack {
            Label(filter.title, systemImage: filter.symbol)
            Spacer()
            Text("\(store.count(for: filter))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

struct ContentAreaView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch store.connectionState {
                case .starting:
                    ConnectionStateView(
                        title: L10n.tr("正在连接"),
                        message: L10n.tr("正在启动 aria2-next 引擎"),
                        symbol: "hourglass",
                        primaryActionTitle: nil,
                        secondaryActionTitle: nil
                    )
                case .failed:
                    ConnectionStateView(
                        title: L10n.tr("无法连接"),
                        message: L10n.tr("请重试连接或检查引擎设置。"),
                        symbol: "wifi.slash",
                        primaryActionTitle: L10n.tr("重试连接"),
                        secondaryActionTitle: L10n.tr("打开设置")
                    )
                case .stopped:
                    ConnectionStateView(
                        title: L10n.tr("引擎已停止"),
                        message: L10n.tr("下载引擎没有运行"),
                        symbol: "stop.circle",
                        primaryActionTitle: L10n.tr("重新连接"),
                        secondaryActionTitle: L10n.tr("打开设置")
                    )
                case .connected:
                    if store.selectedFilter == .history {
                        HistoryListView()
                    } else if store.filteredTasks.isEmpty && store.taskSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        EmptyTaskView()
                    } else {
                        TaskListView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            StatusBarView()
        }
        .navigationTitle(store.selectedFilter.title)
    }
}
