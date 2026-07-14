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
                    Label("添加", systemImage: "plus")
                }
                .disabled(store.connectionState != .connected)
                .help("添加任务")

                Button {
                    Task {
                        await store.resumeSelected()
                    }
                } label: {
                    Label("继续", systemImage: "play.fill")
                }
                .disabled(store.connectionState != .connected || !store.canResumeSelected)
                .help("继续选中的任务")

                Button {
                    Task {
                        await store.pauseSelected()
                    }
                } label: {
                    Label("暂停", systemImage: "pause.fill")
                }
                .disabled(store.connectionState != .connected || !store.canPauseSelected)
                .help("暂停选中的任务")

                Button {
                    store.showDeleteConfirmation = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
                .disabled(store.connectionState != .connected || store.selectedTask == nil)
                .help("删除选中的任务")

                Button {
                    Task {
                        await store.refreshTasksFromEngine()
                    }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(store.connectionState != .connected)
                .help("刷新任务列表")
            }

            ToolbarItemGroup(placement: .automatic) {
                Button {
                    openSettings()
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
                .help("打开设置")
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
            Section("下载任务") {
                ForEach(taskFilters) { filter in
                    SidebarFilterRow(filter: filter)
                        .tag(filter)
                }
            }

            Section("资料库") {
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
                        title: "正在连接",
                        message: "正在启动 aria2-next 引擎",
                        symbol: "hourglass",
                        primaryActionTitle: nil,
                        secondaryActionTitle: nil
                    )
                case .failed:
                    ConnectionStateView(
                        title: "无法连接",
                        message: "请重试连接或检查引擎设置。",
                        symbol: "wifi.slash",
                        primaryActionTitle: "重试连接",
                        secondaryActionTitle: "打开设置"
                    )
                case .stopped:
                    ConnectionStateView(
                        title: "引擎已停止",
                        message: "下载引擎没有运行",
                        symbol: "stop.circle",
                        primaryActionTitle: "重新连接",
                        secondaryActionTitle: "打开设置"
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

struct ConnectionStateView: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var store: AppStore
    let title: String
    let message: String
    let symbol: String
    let primaryActionTitle: String?
    let secondaryActionTitle: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title2.bold())

            Text(message)
                .foregroundStyle(.secondary)

            HStack {
                if let primaryActionTitle {
                    Button(primaryActionTitle) {
                        Task { @MainActor in
                            await store.retryEngineConnection()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let secondaryActionTitle {
                    Button(secondaryActionTitle) {
                        openSettings()
                    }
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyTaskView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("没有下载任务")
                .font(.title2.bold())

            Text("添加链接或打开 torrent 文件")
                .foregroundStyle(.secondary)

            Button("添加任务") {
                store.showAddTask = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TaskListView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("\(store.filteredTasks.count) 个任务")
                    .font(.headline)

                Picker("排序", selection: $store.taskSort) {
                    ForEach(TaskSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .labelsHidden()
                .frame(width: 96)

                Spacer()

                Button("清理结果") {
                    Task {
                        await store.clearStoppedResults()
                    }
                }
                .disabled(store.connectionState != .connected || (store.completeCount + store.failedCount) == 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)

            Divider()

            Group {
                if store.filteredTasks.isEmpty {
                    ContentUnavailableView(
                        "没有匹配任务",
                        systemImage: "magnifyingglass",
                        description: Text("调整搜索关键词或切换筛选项")
                    )
                } else {
                    List {
                        ForEach(store.filteredTasks) { task in
                            TaskRowView(task: task, isSelected: store.selectedTaskID == task.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.selectedTaskID = task.id
                                }
                                .contextMenu {
                                    Button("继续") {
                                        store.selectedTaskID = task.id
                                        Task { await store.resumeSelected() }
                                    }
                                    .disabled(!task.status.canResume)

                                    Button("暂停") {
                                        store.selectedTaskID = task.id
                                        Task { await store.pauseSelected() }
                                    }
                                    .disabled(!task.status.canPause)

                                    Divider()

                                    Button("打开文件夹") {
                                        openLocation(for: task)
                                    }

                                    Button("复制链接") {
                                        if let sourceLink = task.sourceLink {
                                            copyToPasteboard(sourceLink)
                                        }
                                    }
                                    .disabled(task.sourceLink == nil)

                                    Button("复制 GID") {
                                        copyToPasteboard(task.gid)
                                    }

                                    Button("复制任务信息") {
                                        copyToPasteboard(store.taskSummary(for: task))
                                    }

                                    Divider()

                                    Button("删除...", role: .destructive) {
                                        store.selectedTaskID = task.id
                                        store.showDeleteConfirmation = true
                                    }
                                }
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .searchable(text: $store.taskSearchText, placement: .toolbar, prompt: "搜索任务、路径或 GID")
        .onAppear {
            if store.selectedTaskID == nil {
                store.selectedTaskID = store.filteredTasks.first?.id
            }
        }
        .onChange(of: store.selectedFilter) {
            store.selectedTaskID = store.filteredTasks.first?.id
        }
    }

    private func openLocation(for task: DownloadTask) {
        let path = task.localFilePaths.first ?? task.savePath
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }

        let parentURL = url.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: parentURL.path) {
            NSWorkspace.shared.open(parentURL)
        }
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

struct TaskRowView: View {
    let task: DownloadTask
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                StatusDot(status: task.status)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                }

                Spacer()

                Text(task.status.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(task.status.color)
            }

            HStack(spacing: 10) {
                ProgressView(value: task.progress)
                    .tint(task.status.color)

                Text("↓ \(task.downloadSpeed)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 86, alignment: .trailing)
            }

            HStack {
                Text(task.remainingTime)
                Text("\(Int(task.progress * 100))%")
                Text("\(task.completedSize) / \(task.totalSize)")
                Spacer()
                if task.uploadSpeed != "0 KB/s" {
                    Text("↑ \(task.uploadSpeed)")
                }
                TaskRowActions(task: task)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    if isSelected || isHovering {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(isSelected ? 0.05 : 0.025))
                    }
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected
                        ? Color.primary.opacity(0.2)
                        : Color(nsColor: .separatorColor).opacity(isHovering ? 0.8 : 0.45),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(isHovering ? 0.08 : 0), radius: 4, y: 1)
        .overlay(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .padding(.vertical, 10)
                    .padding(.leading, 3)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

struct TaskRowActions: View {
    @EnvironmentObject private var store: AppStore
    let task: DownloadTask

    var body: some View {
        HStack(spacing: 2) {
            Button {
                store.selectedTaskID = task.id
                Task {
                    if task.status.canPause {
                        await store.pauseSelected()
                    } else if task.status.canResume {
                        await store.resumeSelected()
                    }
                }
            } label: {
                Image(systemName: task.status.canPause ? "pause.fill" : "play.fill")
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.borderless)
            .disabled(!task.status.canPause && !task.status.canResume)
            .help(task.status.canPause ? "暂停任务" : "继续任务")

            Button {
                revealInFinder()
            } label: {
                Image(systemName: "folder")
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.borderless)
            .help("在 Finder 中显示")

            Button {
                if let sourceLink = task.sourceLink {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(sourceLink, forType: .string)
                }
            } label: {
                Image(systemName: "link")
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.borderless)
            .disabled(task.sourceLink == nil)
            .help("复制链接")

            Button(role: .destructive) {
                store.selectedTaskID = task.id
                store.showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.borderless)
            .help("删除任务")
        }
        .controlSize(.small)
    }

    private func revealInFinder() {
        let path = task.localFilePaths.first ?? task.savePath
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }

        let parentURL = url.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: parentURL.path) {
            NSWorkspace.shared.open(parentURL)
        }
    }
}

struct StatusDot: View {
    let status: TaskStatus

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 9, height: 9)
            .accessibilityLabel(status.title)
    }
}

struct HistoryListView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("\(store.filteredHistory.count) 条历史")
                    .font(.headline)

                Spacer()

                Button("清空历史", role: .destructive) {
                    store.clearHistory()
                }
                .disabled(store.history.isEmpty)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)

            Divider()

            Group {
                if store.filteredHistory.isEmpty {
                    ContentUnavailableView(
                        store.historySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "没有历史记录" : "没有匹配历史",
                        systemImage: "clock.arrow.circlepath",
                        description: Text(store.historySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "删除或完成的任务会显示在这里" : "调整搜索关键词")
                    )
                } else {
                    List(store.filteredHistory) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Text(item.result)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(item.result.contains("失败") ? .red : .green)
                                Text(item.finishedAt)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text(item.location)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()

                                Button("复制位置") {
                                    copyToPasteboard(item.location)
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)

                                if canOpenLocation(item.location) {
                                    Button("打开位置") {
                                        openHistoryLocation(item.location)
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption)
                                }
                            }
                        }
                        .padding(.vertical, 7)
                    }
                    .listStyle(.inset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .searchable(text: $store.historySearchText, placement: .toolbar, prompt: "搜索历史")
    }

    private func canOpenLocation(_ location: String) -> Bool {
        let expandedPath = (location as NSString).expandingTildeInPath
        return expandedPath.hasPrefix("/")
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func openHistoryLocation(_ location: String) {
        let expandedPath = (location as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }

        let parentURL = url.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: parentURL.path) {
            NSWorkspace.shared.open(parentURL)
        }
    }
}

struct StatusBarView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(store.connectionState.color)
                .frame(width: 8, height: 8)

            Text(store.connectionState.title)
                .foregroundStyle(store.connectionState.color)
                .fontWeight(.medium)

            Divider()
                .frame(height: 16)

            Text("↓ \(store.downloadSpeedText)")
            Text("↑ \(store.uploadSpeedText)")

            Divider()
                .frame(height: 16)

            Text("\(store.activeCount) 个下载中")
            Text("\(store.waitingCount) 个等待中")
            Text("\(store.completeCount) 个已完成")
            Text("\(store.failedCount) 个已失败")

            Spacer()
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 28)
    }
}

struct AddTaskSheet: View {
    @EnvironmentObject private var store: AppStore
    @State private var tab = "url"
    @State private var urlText = ""
    @State private var fileName = ""
    @State private var downloadDirectory = ""
    @State private var splitCount = 64

    private var hasURLInput: Bool {
        !parsedURLs.isEmpty
    }

    private var hasInvalidURLInput: Bool {
        let lines = urlText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return !lines.isEmpty && lines.count != parsedURLs.count
    }

    private var parsedURLs: [String] {
        urlText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { isSupportedURL($0) }
    }

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 14) {
                    sheetContent
                }
            } else {
                sheetContent
            }
        }
        .onAppear {
            downloadDirectory = store.settings.downloadDirectory
            splitCount = store.settings.splitCount
        }
    }

    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            taskForm

            Spacer(minLength: 0)

            footer
        }
        .padding(24)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("新建任务")
                    .font(.title3.weight(.semibold))

                Text(tab == "url" ? "添加链接、磁力或 ED2K 下载" : "导入 torrent 并选择文件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("任务类型", selection: $tab) {
                Text("链接").tag("url")
                Text("Torrent").tag("torrent")
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 196)
        }
    }

    @ViewBuilder
    private var taskForm: some View {
        if tab == "url" {
            urlTaskForm
        } else {
            torrentTaskForm
        }
    }

    private var urlTaskForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            glassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        Label("下载链接", systemImage: "link")
                            .font(.headline)

                        Spacer()

                        Button {
                            pasteURLText()
                        } label: {
                            Label("粘贴", systemImage: "doc.on.clipboard")
                        }
                        .ariaFlowGlassButtonStyle()
                        .controlSize(.small)
                    }

                    urlEditor

                    if hasInvalidURLInput {
                        Label("仅支持 http、https、ftp、magnet 和 ed2k 链接。", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            glassPanel {
                VStack(spacing: 10) {
                    directoryRow
                    fileNameRow
                    splitCountRow
                }
            }
        }
    }

    private var torrentTaskForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            glassPanel {
                HStack(spacing: 14) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Torrent 文件")
                            .font(.headline)
                        Text("拖入 .torrent 文件，或从 Finder 选择")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("选择...") {
                        chooseTorrentFile()
                    }
                    .ariaFlowGlassButtonStyle()
                }
                .frame(height: 92)
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleTorrentDrop(providers)
            }

            glassPanel {
                VStack(spacing: 10) {
                    directoryRow
                    fileNameRow
                    splitCountRow
                }
            }
        }
    }

    private var urlEditor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)

            TextEditor(text: $urlText)
                .font(.callout.monospaced())
                .scrollContentBackground(.hidden)
                .padding(8)

            if urlText.isEmpty {
                Text("https://example.com/file.zip")
                    .font(.callout.monospaced())
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 13)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 104)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(hasInvalidURLInput ? Color.red.opacity(0.7) : Color(nsColor: .separatorColor).opacity(0.65), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func glassPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(macOS 26.0, *) {
            content()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            content()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
                }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(tab == "url" ? "\(parsedURLs.count) 个有效链接" : "选择 torrent 后会读取文件列表")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("取消") {
                store.showAddTask = false
            }
            .ariaFlowGlassButtonStyle()
            .keyboardShortcut(.cancelAction)

            if tab == "url" {
                Button("开始下载") {
                    Task {
                        await store.addURLTask(urlText: parsedURLs.joined(separator: "\n"), fileName: fileName, splitCount: splitCount, downloadDirectory: downloadDirectory)
                    }
                }
                .ariaFlowGlassButtonStyle(prominent: true)
                .keyboardShortcut(.defaultAction)
                .disabled(!hasURLInput || hasInvalidURLInput)
            } else {
                Button("选择 Torrent...") {
                    chooseTorrentFile()
                }
                .ariaFlowGlassButtonStyle(prominent: true)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var directoryRow: some View {
        formRow("保存到") {
            HStack(spacing: 8) {
                Text(downloadDirectory)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Button("选择...") {
                    chooseDownloadDirectory()
                }
                .ariaFlowGlassButtonStyle()
                .controlSize(.small)
            }
        }
    }

    private var fileNameRow: some View {
        formRow("文件名") {
            TextField("自动识别", text: $fileName)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var splitCountRow: some View {
        formRow("分片数") {
            HStack(spacing: 8) {
                Text("\(splitCount)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .leading)

                Stepper("分片数", value: $splitCount, in: 1...64)
                    .labelsHidden()
                    .controlSize(.small)

                Spacer()
            }
        }
    }

    private func formRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)

            content()
        }
        .font(.callout)
    }

    private func chooseDownloadDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "选择"

        if panel.runModal() == .OK, let url = panel.url {
            downloadDirectory = url.path
        }
    }

    private func pasteURLText() {
        if let text = NSPasteboard.general.string(forType: .string) {
            urlText = text
        }
    }

    private func isSupportedURL(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        return lowercased.hasPrefix("http://")
            || lowercased.hasPrefix("https://")
            || lowercased.hasPrefix("ftp://")
            || lowercased.hasPrefix("magnet:")
            || lowercased.hasPrefix("ed2k://")
    }

    private func chooseTorrentFile() {
        let panel = NSOpenPanel()
        if let torrentType = UTType(filenameExtension: "torrent") {
            panel.allowedContentTypes = [torrentType]
        }
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await store.addTorrentTask(fileURL: url, splitCount: splitCount, downloadDirectory: downloadDirectory)
            }
        }
    }

    private func handleTorrentDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = item as? URL
            }

            guard let url, url.pathExtension.lowercased() == "torrent" else { return }
            Task { @MainActor in
                await store.addTorrentTask(fileURL: url, splitCount: splitCount, downloadDirectory: downloadDirectory)
            }
        }
        return true
    }
}

private extension View {
    @ViewBuilder
    func ariaFlowGlassButtonStyle(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else if prominent {
            buttonStyle(.borderedProminent)
        } else {
            buttonStyle(.bordered)
        }
    }
}

struct FileSelectionSheet: View {
    @EnvironmentObject private var store: AppStore

    private var selectedCount: Int {
        store.fileCandidates.filter(\.isSelected).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择要下载的文件")
                .font(.title2.bold())

            if store.fileCandidates.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在读取文件列表")
                        .font(.headline)
                    Text("Torrent 或 magnet 元数据解析完成后，可以选择要下载的文件。")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 250)
            } else {
                Toggle("全选", isOn: allSelectedBinding)
                    .font(.headline)

                Button("反选") {
                    for index in store.fileCandidates.indices {
                        store.fileCandidates[index].isSelected.toggle()
                    }
                }

                List {
                    ForEach($store.fileCandidates) { $file in
                        HStack {
                            Toggle(file.name, isOn: $file.isSelected)
                            Spacer()
                            Text(file.size)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
                .frame(minHeight: 210)

                Text("已选择 \(selectedCount) 个文件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button("取消任务") {
                    Task {
                        await store.cancelFileSelection()
                    }
                }

                Button("开始下载") {
                    Task {
                        await store.startSelectedFilesDownload()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCount == 0)
            }
        }
        .padding(22)
    }

    private var allSelectedBinding: Binding<Bool> {
        Binding {
            store.fileCandidates.allSatisfy(\.isSelected)
        } set: { newValue in
            for index in store.fileCandidates.indices {
                store.fileCandidates[index].isSelected = newValue
            }
        }
    }
}

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case downloads
    case engine
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "通用"
        case .downloads: "下载"
        case .engine: "引擎"
        case .about: "关于"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .downloads: "arrow.down.to.line.compact"
        case .engine: "gearshape.2"
        case .about: "info.circle"
        }
    }
}

struct SettingsWindowView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedCategory: SettingsCategory = .general
    @State private var showLoginItemGuide = false

    private var launchInMenuBarBinding: Binding<Bool> {
        Binding {
            !store.settings.showMainWindowOnLaunch
        } set: { launchInMenuBar in
            store.settings.showMainWindowOnLaunch = !launchInMenuBar
        }
    }

    private var hideDockIconBinding: Binding<Bool> {
        Binding {
            store.settings.hideDockIconInMenuBarMode
        } set: { hideDockIcon in
            store.settings.hideDockIconInMenuBarMode = hideDockIcon
            AppPresentation.updateActivationPolicy(store: store)
        }
    }

    private var rpcPortBinding: Binding<String> {
        Binding {
            String(store.settings.rpcPort)
        } set: { value in
            let digits = value.filter(\.isNumber)
            guard let port = Int(digits), port > 0 else { return }
            store.setRPCPort(port)
        }
    }

    private var rpcSecretBinding: Binding<String> {
        Binding {
            store.rpcSecret
        } set: { value in
            store.setRPCSecret(value)
        }
    }

    private var rpcSecretFieldWidth: CGFloat {
        let characterCount = max(store.rpcSecret.count, 8)
        return min(max(CGFloat(characterCount) * 8 + 26, 90), 280)
    }

    private var canRunInMenuBar: Bool {
        !store.settings.showMainWindowOnLaunch || store.settings.keepRunningAfterMainWindowClose
    }

    var body: some View {
        TabView(selection: $selectedCategory) {
            ForEach(SettingsCategory.allCases) { category in
                Form {
                    settingsDetail(for: category)
                }
                .formStyle(.grouped)
                .contentMargins(.top, 8, for: .scrollContent)
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .contentMargins(.bottom, 8, for: .scrollContent)
                .tabItem {
                    Label(category.title, systemImage: category.symbol)
                }
                .tag(category)
            }
        }
        .frame(width: 400, height: 360)
        .alert("添加登录项", isPresented: $showLoginItemGuide) {
            Button("好", role: .cancel) {}
        } message: {
            Text("在“登录时打开”列表中点击 +，然后选择 Applications 文件夹内的 AriaFlow.app。")
        }
    }

    @ViewBuilder
    private func settingsDetail(for category: SettingsCategory) -> some View {
        switch category {
        case .general:
            settingsPanel(title: "启动与常驻", symbol: "gearshape") {
                toggleRow("菜单栏显示速度", isOn: $store.settings.showSpeedInMenuBar)
                settingsRow("登录时自动启动", detail: "在系统设置中手动添加") {
                    Button("打开登录项与扩展") {
                        store.openLoginItemSettings()
                        showLoginItemGuide = true
                    }
                    .controlSize(.small)
                }

                toggleRow("启动时进入菜单栏", isOn: launchInMenuBarBinding)
                toggleRow("关闭主窗口后继续运行", isOn: $store.settings.keepRunningAfterMainWindowClose)
                toggleRow("菜单栏运行时隐藏 Dock 图标", isOn: hideDockIconBinding)
                    .disabled(!canRunInMenuBar)
            }

            settingsPanel(title: "维护", symbol: "arrow.counterclockwise") {
                settingsRow("恢复默认设置", detail: nil) {
                    Button("恢复默认设置", role: .destructive) {
                        store.resetSettings()
                    }
                }
            }

        case .downloads:
            settingsPanel(title: "保存位置", symbol: "folder") {
                settingsRow("默认保存位置", detail: nil) {
                    HStack(spacing: 8) {
                        pathValue(store.settings.downloadDirectory)
                        chooseDirectoryButton
                    }
                }
            }

            settingsPanel(title: "队列与速度", symbol: "speedometer") {
                settingsRow("最大同时下载数", detail: nil) {
                    HStack(spacing: 8) {
                        TextField("5", value: $store.settings.maxConcurrentDownloads, format: .number)
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 56)
                            .onSubmit {
                                store.normalizeSettings()
                                applyRuntimeDownloadSettings()
                            }

                        Stepper("最大同时下载数", value: $store.settings.maxConcurrentDownloads, in: 1...10)
                            .labelsHidden()
                            .controlSize(.small)
                    }
                    .onChange(of: store.settings.maxConcurrentDownloads) {
                        store.normalizeSettings()
                        applyRuntimeDownloadSettings()
                    }
                }

                settingsRow("默认分片数", detail: nil) {
                    HStack(spacing: 8) {
                        TextField("64", value: $store.settings.splitCount, format: .number)
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 56)
                            .onSubmit {
                                store.normalizeSettings()
                            }

                        Stepper("默认分片数", value: $store.settings.splitCount, in: 1...64)
                            .labelsHidden()
                            .controlSize(.small)
                    }
                    .onChange(of: store.settings.splitCount) {
                        store.normalizeSettings()
                    }
                }

                settingsRow("HTTP 单服务器最大连接数", detail: nil) {
                    HStack(spacing: 8) {
                        TextField("64", value: $store.settings.maxConnectionsPerServer, format: .number)
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 56)
                            .onSubmit {
                                store.normalizeSettings()
                            }

                        Stepper("HTTP 单服务器最大连接数", value: $store.settings.maxConnectionsPerServer, in: 1...64)
                            .labelsHidden()
                            .controlSize(.small)
                    }
                    .onChange(of: store.settings.maxConnectionsPerServer) {
                        store.normalizeSettings()
                    }
                }

                settingsRow("下载限速", detail: nil) {
                    HStack(spacing: 6) {
                        TextField("0", value: $store.settings.downloadSpeedLimit, format: .number)
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 72)

                        Text("Mb/s")
                            .foregroundStyle(.secondary)
                    }
                    .onChange(of: store.settings.downloadSpeedLimit) {
                        store.normalizeSettings()
                        applyRuntimeDownloadSettings()
                    }
                }

                settingsRow("上传限速", detail: nil) {
                    HStack(spacing: 6) {
                        TextField("0", value: $store.settings.uploadSpeedLimit, format: .number)
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 72)

                        Text("Mb/s")
                            .foregroundStyle(.secondary)
                    }
                    .onChange(of: store.settings.uploadSpeedLimit) {
                        store.normalizeSettings()
                        applyRuntimeDownloadSettings()
                    }
                }
            }

        case .engine:
            settingsPanel(title: "RPC", symbol: "network") {
                settingsRow("RPC 端口", detail: nil) {
                    TextField("", text: rpcPortBinding, prompt: Text("6800"))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }

                settingsRow("RPC Secret", detail: nil) {
                    TextField("", text: rpcSecretBinding, prompt: Text("空"))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: rpcSecretFieldWidth)
                }

                HStack(alignment: .center, spacing: 18) {
                    HStack(spacing: 6) {
                        Text("引擎状态")
                            .font(.body)

                        if store.rpcPortNeedsRestart {
                            Text("RPC 端口修改后需重启")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 16)

                    Label(store.connectionState.title, systemImage: store.connectionState.symbol)
                        .foregroundStyle(store.connectionState.color)

                    Button("重启引擎") {
                        restartEngine()
                    }
                    .controlSize(.small)
                    .disabled(store.connectionState == .starting)
                }
            }

            settingsPanel(title: "引擎操作", subtitle: "这些操作会影响当前下载引擎状态", symbol: "terminal") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button("重试连接") {
                            retryConnection()
                        }

                        Button("停止引擎") {
                            Task {
                                await store.stopEngineSavingSession()
                            }
                        }

                        Button("保存会话") {
                            saveSession()
                        }
                    }

                    HStack(spacing: 8) {
                        Button("打开日志") {
                            openLogFolder()
                        }

                        Button("打开数据目录") {
                            openDataFolder()
                        }
                    }
                }
                .controlSize(.regular)
            }

            settingsPanel(
                title: "BT Peer Blocklist",
                subtitle: "每行填写一个 IPv4、IPv6 或 CIDR；空行和 # 注释会被忽略。",
                symbol: "shield.lefthalf.filled"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("规则文件")
                        Spacer()
                        Button("选择...") {
                            choosePeerBlocklist()
                        }
                        .controlSize(.small)
                    }

                    pathValue(
                        store.settings.btPeerBlocklistPath.isEmpty
                            ? "未选择"
                            : store.settings.btPeerBlocklistPath
                    )

                    Text(store.peerBlocklistMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Spacer()

                        Button("重新加载") {
                            Task {
                                await store.reloadPeerBlocklist()
                            }
                        }
                        .disabled(store.settings.btPeerBlocklistPath.isEmpty)

                        Button("清除") {
                            Task {
                                await store.clearPeerBlocklist()
                            }
                        }
                        .disabled(store.settings.btPeerBlocklistPath.isEmpty)
                    }
                    .controlSize(.small)
                }
            }

        case .about:
            settingsPanel(title: "AriaFlow", symbol: "info.circle") {
                settingsRow("软件版本", detail: nil) {
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }

                settingsRow("Aria2 Next 版本", detail: nil) {
                    Text("2.5.1")
                        .foregroundStyle(.secondary)
                }

                settingsRow("GitHub", detail: nil) {
                    Link("FateLightX/AriaFlow", destination: ariaFlowRepositoryURL)
                        .lineLimit(1)
                }

                settingsRow("官网", detail: nil) {
                    Link("aria2.github.io", destination: aria2WebsiteURL)
                        .lineLimit(1)
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
    }

    private var ariaFlowRepositoryURL: URL {
        URL(string: "https://github.com/FateLightX/AriaFlow")!
    }

    private var aria2WebsiteURL: URL {
        URL(string: "https://aria2.github.io/")!
    }

    private func settingsPanel<Content: View>(
        title: String,
        subtitle: String? = nil,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Section {
            VStack(spacing: 10) {
                content()
            }
        } header: {
            Label(title, systemImage: symbol)
                .font(.headline)
        } footer: {
            if let subtitle {
                Text(subtitle)
            }
        }
    }

    private func settingsRow<Content: View>(
        _ title: String,
        detail: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 16)
            content()
        }
    }

    private func toggleRow(_ title: String, detail: String? = nil, isOn: Binding<Bool>) -> some View {
        settingsRow(title, detail: detail) {
            Toggle(title, isOn: isOn)
                .labelsHidden()
        }
    }

    private func pathValue(_ value: String) -> some View {
        Text(value)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var chooseDirectoryButton: some View {
        Button("选择...") {
            chooseDownloadDirectory()
        }
        .controlSize(.small)
    }

    private func stepperValue<Content: View>(_ value: String, @ViewBuilder control: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
            control()
        }
    }

    private func chooseDownloadDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "选择"

        if panel.runModal() == .OK, let url = panel.url {
            store.settings.downloadDirectory = url.path
        }
    }

    private func choosePeerBlocklist() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await store.setPeerBlocklist(path: url.path)
            }
        }
    }

    private func retryConnection() {
        Task { @MainActor in
            await store.retryEngineConnection()
        }
    }

    private func applyRuntimeDownloadSettings() {
        Task {
            await store.applyRuntimeDownloadSettings()
        }
    }

    private func saveSession() {
        Task {
            await store.saveSession()
        }
    }

    private func restartEngine() {
        Task { @MainActor in
            await store.restartEngineNowSavingSession()
        }
    }

    private func openLogFolder() {
        LocalAppFiles.ensureDirectory()
        if !FileManager.default.fileExists(atPath: LocalAppFiles.logURL.path) {
            FileManager.default.createFile(atPath: LocalAppFiles.logURL.path, contents: nil)
        }
        NSWorkspace.shared.activateFileViewerSelecting([LocalAppFiles.logURL])
    }

    private func openDataFolder() {
        LocalAppFiles.ensureDirectory()
        NSWorkspace.shared.open(LocalAppFiles.directory)
    }

}

struct DeleteConfirmationSheet: View {
    @EnvironmentObject private var store: AppStore
    @State private var deleteFiles = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("删除任务？")
                .font(.title2.bold())

            Text("这会从 AriaFlow 中移除选中的任务。已下载的文件默认会保留在磁盘上。")
                .foregroundStyle(.secondary)

            Toggle("同时删除本地文件", isOn: $deleteFiles)

            if deleteFiles {
                let targets = store.selectedTask.map { store.deleteFileTargets(for: $0) } ?? []
                VStack(alignment: .leading, spacing: 4) {
                    Text("将把 \(targets.count) 个文件或文件夹移到废纸篓。")
                    ForEach(Array(targets.prefix(3).enumerated()), id: \.offset) { _, path in
                        Text(path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if targets.count > 3 {
                        Text("另有 \(targets.count - 3) 项")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button("取消") {
                    store.showDeleteConfirmation = false
                }

                Button(deleteFiles ? "删除任务和文件" : "删除任务", role: .destructive) {
                    Task {
                        await store.deleteSelected(deleteFiles: deleteFiles)
                        store.showDeleteConfirmation = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
    }
}
