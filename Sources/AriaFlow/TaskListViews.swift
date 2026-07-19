import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
            if store.taskListTruncated {
                Text("列表过长已截断")
                    .foregroundStyle(.orange)
            }

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
