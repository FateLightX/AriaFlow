import SwiftUI

enum LocalAppFiles {
    static var directory: URL {
        if let override = ProcessInfo.processInfo.environment["ARIAFLOW_APP_SUPPORT_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines), !override.isEmpty {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath, isDirectory: true)
        }

        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return baseURL.appending(path: "AriaFlow", directoryHint: .isDirectory)
    }

    static var settingsURL: URL {
        directory.appending(path: "settings.json")
    }

    static var historyURL: URL {
        directory.appending(path: "history.json")
    }

    static var logURL: URL {
        directory.appending(path: "aria2-next.log")
    }

    static var sessionURL: URL {
        directory.appending(path: "download.session")
    }

    static var rpcSecretURL: URL {
        directory.appending(path: "rpc-secret.txt")
    }

    static func ensureDirectory() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

enum LocalJSONStore {
    static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, to url: URL) {
        LocalAppFiles.ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

enum LocalSecretStore {
    static func load() -> String {
        LocalAppFiles.ensureDirectory()
        if let secret = try? String(contentsOf: LocalAppFiles.rpcSecretURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) {
            return secret
        }

        return ""
    }

    static func save(_ secret: String) {
        LocalAppFiles.ensureDirectory()
        try? secret.write(to: LocalAppFiles.rpcSecretURL, atomically: true, encoding: .utf8)
    }
}

enum ConnectionState: String, CaseIterable, Identifiable {
    case starting
    case connected
    case failed
    case stopped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .starting: "正在连接"
        case .connected: "已连接"
        case .failed: "连接失败"
        case .stopped: "已停止"
        }
    }

    var detail: String {
        switch self {
        case .starting: "正在启动 aria2-next 引擎"
        case .connected: "aria2-next RPC 已连接"
        case .failed: "无法连接 aria2-next RPC"
        case .stopped: "下载引擎已停止"
        }
    }

    var color: Color {
        switch self {
        case .starting: .orange
        case .connected: .green
        case .failed: .red
        case .stopped: .secondary
        }
    }

    var symbol: String {
        switch self {
        case .starting: "hourglass"
        case .connected: "checkmark.circle.fill"
        case .failed: "wifi.slash"
        case .stopped: "stop.circle"
        }
    }
}

enum TaskFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case waiting
    case complete
    case failed
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .active: "下载中"
        case .waiting: "等待中"
        case .complete: "已完成"
        case .failed: "已失败"
        case .history: "历史"
        }
    }

    var symbol: String {
        switch self {
        case .all: "tray.full"
        case .active: "arrow.down.circle"
        case .waiting: "clock"
        case .complete: "checkmark.circle"
        case .failed: "xmark.circle"
        case .history: "clock.arrow.circlepath"
        }
    }
}

enum TaskStatus: String {
    case active
    case waiting
    case paused
    case complete
    case failed

    var title: String {
        switch self {
        case .active: "下载中"
        case .waiting: "等待中"
        case .paused: "已暂停"
        case .complete: "已完成"
        case .failed: "已失败"
        }
    }

    var color: Color {
        switch self {
        case .active: .blue
        case .waiting, .paused: .orange
        case .complete: .green
        case .failed: .red
        }
    }

    var canPause: Bool {
        self == .active || self == .waiting
    }

    var canResume: Bool {
        self == .paused || self == .waiting
    }
}

enum TaskSort: String, CaseIterable, Identifiable {
    case status
    case name
    case progress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .status: "状态"
        case .name: "名称"
        case .progress: "进度"
        }
    }
}

struct DownloadTask: Identifiable, Hashable {
    var name: String
    var protocolLabel: String
    var status: TaskStatus
    var progress: Double
    var completedSize: String
    var totalSize: String
    var downloadSpeed: String
    var uploadSpeed: String
    var remainingTime: String
    var savePath: String
    var gid: String
    var detail: String
    var errorMessage: String?
    var fileNames: [String]
    var localFilePaths: [String]
    var sourceURLs: [String]
    var infoHash: String?
    var ed2kHash: String?

    var id: String { gid }

    var sourceLink: String? {
        if let sourceURL = sourceURLs.first {
            return sourceURL
        }
        if let infoHash, !infoHash.isEmpty {
            return "magnet:?xt=urn:btih:\(infoHash)"
        }
        return nil
    }
}

struct HistoryItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var gid: String?
    var name: String
    var result: String
    var finishedAt: String
    var location: String
}

struct FileCandidate: Identifiable {
    let id = UUID()
    var aria2Index = ""
    var name: String
    var size: String
    var isSelected: Bool
}

struct AppSettings: Codable {
    var autoConnectEngine = true
    var downloadDirectory = "~/Downloads"
    var maxConcurrentDownloads = 5
    var splitCount = 64
    var maxConnectionsPerServer = 64
    var downloadSpeedLimit = 0
    var uploadSpeedLimit = 0
    var showSpeedInMenuBar = true
    var showMainWindowOnLaunch = true
    var keepRunningAfterMainWindowClose = true
    var hideDockIconInMenuBarMode = true
    var btPeerBlocklistPath = ""
    var rpcPort = 6800

    private enum CodingKeys: String, CodingKey {
        case autoConnectEngine
        case downloadDirectory
        case maxConcurrentDownloads
        case splitCount
        case maxConnectionsPerServer
        case downloadSpeedLimit
        case uploadSpeedLimit
        case showSpeedInMenuBar
        case showMainWindowOnLaunch
        case keepRunningAfterMainWindowClose
        case hideDockIconInMenuBarMode
        case btPeerBlocklistPath
        case rpcPort
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        autoConnectEngine = try container.decodeIfPresent(Bool.self, forKey: .autoConnectEngine) ?? true
        downloadDirectory = try container.decodeIfPresent(String.self, forKey: .downloadDirectory) ?? "~/Downloads"
        maxConcurrentDownloads = min(max(try container.decodeIfPresent(Int.self, forKey: .maxConcurrentDownloads) ?? 5, 1), 10)
        splitCount = try container.decodeIfPresent(Int.self, forKey: .splitCount) ?? 64
        maxConnectionsPerServer = try container.decodeIfPresent(Int.self, forKey: .maxConnectionsPerServer) ?? 64
        downloadSpeedLimit = Self.decodeSpeedLimit(from: container, forKey: .downloadSpeedLimit)
        uploadSpeedLimit = Self.decodeSpeedLimit(from: container, forKey: .uploadSpeedLimit)
        showSpeedInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showSpeedInMenuBar) ?? true
        showMainWindowOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .showMainWindowOnLaunch) ?? true
        keepRunningAfterMainWindowClose = try container.decodeIfPresent(Bool.self, forKey: .keepRunningAfterMainWindowClose) ?? true
        hideDockIconInMenuBarMode = try container.decodeIfPresent(Bool.self, forKey: .hideDockIconInMenuBarMode) ?? true
        btPeerBlocklistPath = try container.decodeIfPresent(String.self, forKey: .btPeerBlocklistPath) ?? ""
        rpcPort = try container.decodeIfPresent(Int.self, forKey: .rpcPort) ?? 6800
    }

    private static func decodeSpeedLimit(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Int {
        if let value = try? container.decode(Int.self, forKey: key) {
            return max(value, 0)
        }

        if let legacyValue = try? container.decode(String.self, forKey: key),
           let value = Int(legacyValue.filter(\.isNumber)) {
            return max(value, 0)
        }

        return 0
    }
}

@MainActor
final class AppStore: ObservableObject {
    private static let maxHistoryItems = 500
    private static let maxRPCSecretLength = 128
    private static let rpcRestartDelay: Duration = .seconds(1)

    @Published var connectionState: ConnectionState = .stopped
    @Published var engineMessage = "下载引擎未连接"
    @Published var downloadSpeedText = "0 B/s"
    @Published var uploadSpeedText = "0 B/s"
    @Published var selectedFilter: TaskFilter = .all
    @Published var taskSearchText = ""
    @Published var historySearchText = ""
    @Published var taskSort: TaskSort = .status
    @Published var selectedTaskID: DownloadTask.ID?
    @Published var showAddTask = false
    @Published var showFileSelection = false
    @Published var showDeleteConfirmation = false
    @Published var pendingFileSelectionGID: String?
    @Published private(set) var rpcSecret = ""
    @Published private(set) var rpcPortNeedsRestart = false
    @Published private(set) var peerBlocklistMessage = "未配置"
    @Published var settings: AppSettings {
        didSet {
            LocalJSONStore.save(settings, to: LocalAppFiles.settingsURL)
        }
    }
    @Published var fileCandidates: [FileCandidate] = []

    @Published var tasks: [DownloadTask] = []

    @Published var history: [HistoryItem] {
        didSet {
            LocalJSONStore.save(history, to: LocalAppFiles.historyURL)
        }
    }

    private var didAttemptAutomaticConnection = false
    private var pollingTask: Task<Void, Never>?
    private var pendingEngineRestartTask: Task<Void, Never>?
    private let engineManager = EngineManager()
    private let notificationService = NotificationService()
    private let dockService = DockService()
    private var knownTaskStatuses: [String: TaskStatus] = [:]
    private var activeRPCPort: Int?
    private var activeRPCToken: String?

    init() {
        let loadedSettings = LocalJSONStore.load(AppSettings.self, from: LocalAppFiles.settingsURL)
        let loadedHistory = LocalJSONStore.load([HistoryItem].self, from: LocalAppFiles.historyURL)

        settings = loadedSettings ?? AppSettings()
        history = Array((loadedHistory ?? []).prefix(Self.maxHistoryItems))
        if !settings.btPeerBlocklistPath.isEmpty {
            peerBlocklistMessage = "已保存，将在引擎连接时加载"
        }
        let storedRPCSecret = LocalSecretStore.load()
        rpcSecret = Self.normalizedRPCSecret(storedRPCSecret)
        if rpcSecret != storedRPCSecret {
            LocalSecretStore.save(rpcSecret)
        }
        activeRPCPort = settings.rpcPort
        activeRPCToken = rpcSecret
        LoginItemService.removeLegacyLaunchAgent()
        if settings.autoConnectEngine {
            connectionState = .starting
            engineMessage = "正在连接 aria2 RPC"
        }
        notificationService.requestAuthorization()

        if loadedSettings == nil {
            LocalJSONStore.save(settings, to: LocalAppFiles.settingsURL)
        }

        if loadedHistory == nil {
            LocalJSONStore.save(history, to: LocalAppFiles.historyURL)
        }
        updateDockBadge()
    }

    func openLoginItemSettings() {
        LoginItemService.openSystemSettings()
    }

    var selectedTask: DownloadTask? {
        guard let selectedTaskID else { return nil }
        return tasks.first { $0.id == selectedTaskID }
    }

    var filteredTasks: [DownloadTask] {
        let baseTasks: [DownloadTask] = switch selectedFilter {
        case .all:
            tasks
        case .active:
            tasks.filter { $0.status == .active }
        case .waiting:
            tasks.filter { $0.status == .waiting || $0.status == .paused }
        case .complete:
            tasks.filter { $0.status == .complete }
        case .failed:
            tasks.filter { $0.status == .failed }
        case .history:
            []
        }

        let query = taskSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let searchedTasks = query.isEmpty ? baseTasks : baseTasks.filter {
            $0.name.lowercased().contains(query)
                || $0.savePath.lowercased().contains(query)
                || $0.gid.lowercased().contains(query)
                || $0.protocolLabel.lowercased().contains(query)
        }

        return sortedTasks(searchedTasks)
    }

    var filteredHistory: [HistoryItem] {
        let query = historySearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return history }
        return history.filter {
            $0.name.lowercased().contains(query)
                || $0.result.lowercased().contains(query)
                || $0.location.lowercased().contains(query)
                || $0.finishedAt.lowercased().contains(query)
        }
    }

    var canPauseSelected: Bool {
        selectedTask?.status.canPause == true
    }

    var canResumeSelected: Bool {
        selectedTask?.status.canResume == true
    }

    var activeCount: Int { tasks.filter { $0.status == .active }.count }
    var waitingCount: Int { tasks.filter { $0.status == .waiting || $0.status == .paused }.count }
    var completeCount: Int { tasks.filter { $0.status == .complete }.count }
    var failedCount: Int { tasks.filter { $0.status == .failed }.count }

    var activeProgress: Double {
        let activeTasks = tasks.filter { $0.status == .active }
        guard !activeTasks.isEmpty else { return 0 }
        return activeTasks.map(\.progress).reduce(0, +) / Double(activeTasks.count)
    }

    func count(for filter: TaskFilter) -> Int {
        switch filter {
        case .all: tasks.count
        case .active: activeCount
        case .waiting: waitingCount
        case .complete: completeCount
        case .failed: failedCount
        case .history: history.count
        }
    }

    func selectFilter(_ filter: TaskFilter) {
        selectedFilter = filter
        selectedTaskID = filter == .history ? nil : filteredTasks.first?.id
    }

    func pauseSelected() async {
        guard let selectedTask else { return }
        do {
            _ = try await makeClient().pause(gid: selectedTask.gid)
            await refreshTasksFromEngine()
        } catch {
            handleRPCError(error)
        }
    }

    func resumeSelected() async {
        guard let selectedTask else { return }
        do {
            _ = try await makeClient().unpause(gid: selectedTask.gid)
            await refreshTasksFromEngine()
        } catch {
            handleRPCError(error)
        }
    }

    func pauseAll() async {
        do {
            _ = try await makeClient().pauseAll()
            await refreshTasksFromEngine()
        } catch {
            handleRPCError(error)
        }
    }

    func resumeAll() async {
        do {
            _ = try await makeClient().unpauseAll()
            await refreshTasksFromEngine()
        } catch {
            handleRPCError(error)
        }
    }

    func startAutomaticConnectionIfNeeded() async {
        guard settings.autoConnectEngine, !didAttemptAutomaticConnection else { return }
        didAttemptAutomaticConnection = true
        await retryEngineConnection()
    }

    func retryEngineConnection() async {
        connectionState = .starting
        do {
            let client = makeClient()
            let version = try await connectOrStartEngine(client: client)
            try await refreshTasksFromEngine(using: client)
            engineMessage = "aria2 \(version.version) 已连接"
            connectionState = .connected
            await reloadPeerBlocklist()
            startPolling()
        } catch {
            engineMessage = error.localizedDescription
            connectionState = .failed
            stopPolling()
        }
    }

    func stopEngine() {
        stopPolling()
        engineManager.stop()
        connectionState = .stopped
        engineMessage = "下载引擎已停止"
    }

    func stopEngineSavingSession() async {
        stopPolling()
        if connectionState == .connected {
            let client = makeClient()
            _ = try? await client.saveSession()
            if (try? await client.forceShutdown()) != nil {
                try? await waitForExternalEngineToStop(client: client)
                try? await waitForManagedEngineToStop()
            }
        }
        stopEngine()
    }

    func stopEngineForAppTermination() {
        stopPolling()
        pendingEngineRestartTask?.cancel()
        pendingEngineRestartTask = nil
        engineManager.stop()
        connectionState = .stopped
        engineMessage = "下载引擎已停止"
    }

    func restartEngineSavingSession() async {
        engineMessage = "正在重启 aria2 引擎"
        await stopEngineSavingSession()
        await retryEngineConnection()
        if connectionState == .connected {
            rpcPortNeedsRestart = false
        }
    }

    func restartEngineNowSavingSession() async {
        pendingEngineRestartTask?.cancel()
        pendingEngineRestartTask = nil
        await restartEngineSavingSession()
    }

    func saveSession() async {
        guard connectionState == .connected else { return }
        do {
            _ = try await makeClient().saveSession()
            engineMessage = "下载会话已保存"
        } catch {
            engineMessage = "保存下载会话失败：\(error.localizedDescription)"
        }
    }

    func clearStoppedResults() async {
        let removableTasks = tasks.filter { $0.status == .complete || $0.status == .failed }
        guard !removableTasks.isEmpty else { return }

        do {
            let client = makeClient()
            for task in removableTasks {
                _ = try await client.removeDownloadResult(gid: task.gid)
                addHistoryItem(
                    HistoryItem(
                        gid: task.gid,
                        name: task.name,
                        result: "已清理结果",
                        finishedAt: Self.currentTimeText(),
                        location: task.savePath
                    )
                )
            }
            await refreshTasksFromEngine()
        } catch {
            handleRPCError(error)
        }
    }

    func refreshTasksFromEngine() async {
        do {
            try await refreshTasksFromEngine(using: makeClient())
            connectionState = .connected
        } catch {
            engineMessage = error.localizedDescription
            connectionState = .failed
            stopPolling()
        }
    }

    func deleteSelected(deleteFiles: Bool) async {
        guard let task = selectedTask else { return }
        do {
            let client = makeClient()
            if task.status == .complete || task.status == .failed {
                _ = try await client.removeDownloadResult(gid: task.gid)
            } else {
                _ = try await client.forceRemove(gid: task.gid)
            }

            let deleteResult = deleteFiles ? trashLocalFiles(for: task) : nil
            addHistoryItem(
                HistoryItem(
                    gid: task.gid,
                    name: task.name,
                    result: deleteHistoryResult(deleteFiles: deleteFiles, trashResult: deleteResult),
                    finishedAt: Self.currentTimeText(),
                    location: task.savePath
                )
            )
            await refreshTasksFromEngine()
        } catch {
            handleRPCError(error)
        }
    }

    func clearHistory() {
        history.removeAll()
    }

    private func addHistoryItem(_ item: HistoryItem) {
        if let gid = item.gid, history.contains(where: { $0.gid == gid && $0.result == item.result }) {
            return
        }

        history.insert(item, at: 0)
        if history.count > Self.maxHistoryItems {
            history.removeLast(history.count - Self.maxHistoryItems)
        }
    }

    func setRPCPort(_ port: Int) {
        let normalizedPort = min(max(port, 1), 65535)
        guard settings.rpcPort != normalizedPort else { return }
        settings.rpcPort = normalizedPort
        rpcPortNeedsRestart = true
        engineMessage = "RPC 端口已保存，正在重启引擎"
        scheduleAutomaticEngineRestart()
    }

    func setRPCSecret(_ secret: String, restartEngine: Bool = true) {
        let normalizedSecret = Self.normalizedRPCSecret(secret)
        guard rpcSecret != normalizedSecret else { return }
        rpcSecret = normalizedSecret
        LocalSecretStore.save(normalizedSecret)
        engineMessage = "RPC Secret 已保存，正在重启引擎"
        if restartEngine {
            scheduleAutomaticEngineRestart()
        }
    }

    func resetSettings() {
        setRPCSecret("", restartEngine: false)
        settings = AppSettings()
        engineMessage = "设置已恢复默认值"
        peerBlocklistMessage = "未配置"
        if connectionState == .connected {
            Task {
                await clearPeerBlocklist()
            }
        }
    }

    private func scheduleAutomaticEngineRestart() {
        pendingEngineRestartTask?.cancel()
        pendingEngineRestartTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.rpcRestartDelay)
            } catch {
                return
            }

            guard let self, !Task.isCancelled else { return }
            self.pendingEngineRestartTask = nil
            await self.restartEngineSavingSession()
        }
    }

    private static func normalizedRPCSecret(_ secret: String) -> String {
        let bytes = secret.unicodeScalars.compactMap { scalar -> UInt8? in
            guard (33...126).contains(scalar.value) else { return nil }
            return UInt8(scalar.value)
        }
        return String(decoding: bytes.prefix(maxRPCSecretLength), as: UTF8.self)
    }

    func normalizeSettings() {
        settings.rpcPort = min(max(settings.rpcPort, 1), 65535)
        settings.maxConcurrentDownloads = min(max(settings.maxConcurrentDownloads, 1), 10)
        settings.splitCount = min(max(settings.splitCount, 1), 64)
        settings.maxConnectionsPerServer = min(max(settings.maxConnectionsPerServer, 1), 64)
        settings.downloadSpeedLimit = max(settings.downloadSpeedLimit, 0)
        settings.uploadSpeedLimit = max(settings.uploadSpeedLimit, 0)
    }

    private struct TrashResult {
        var total = 0
        var trashed = 0
        var missing = 0
        var failed = 0
        var lastError: String?
        var missingPaths: [String] = []
        var failedPaths: [String] = []
    }

    func deleteFileTargets(for task: DownloadTask) -> [String] {
        let rawPaths = task.localFilePaths
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let fallbackPaths = rawPaths.isEmpty ? [task.savePath] : rawPaths
        let expandedPaths = fallbackPaths
            .map { resolvedDeletePath($0, task: task) }
            .filter { !$0.isEmpty }

        return Array(Set(expandedPaths)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func taskSummary(for task: DownloadTask) -> String {
        var lines = [
            "名称：\(task.name)",
            "GID：\(task.gid)",
            "状态：\(task.status.title)",
            "协议：\(task.protocolLabel)",
            "进度：\(Int((task.progress * 100).rounded()))%",
            "大小：\(task.completedSize) / \(task.totalSize)",
            "下载速度：\(task.downloadSpeed)",
            "上传速度：\(task.uploadSpeed)",
            "剩余时间：\(task.remainingTime)",
            "保存位置：\(task.savePath)"
        ]

        if let infoHash = task.infoHash {
            lines.append("Info hash：\(infoHash)")
        }

        if let ed2kHash = task.ed2kHash {
            lines.append("ED2K hash：\(ed2kHash)")
        }

        if let errorMessage = task.errorMessage {
            lines.append("错误：\(errorMessage)")
        }

        if !task.fileNames.isEmpty {
            lines.append("文件：")
            lines.append(contentsOf: task.fileNames.prefix(20).map { "- \($0)" })
            if task.fileNames.count > 20 {
                lines.append("- 另有 \(task.fileNames.count - 20) 个文件")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func trashLocalFiles(for task: DownloadTask) -> TrashResult {
        var result = TrashResult()
        for expandedPath in deleteFileTargets(for: task) {
            result.total += 1
            guard FileManager.default.fileExists(atPath: expandedPath) else {
                result.missing += 1
                result.missingPaths.append(expandedPath)
                continue
            }

            do {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: URL(fileURLWithPath: expandedPath), resultingItemURL: &trashedURL)
                result.trashed += 1
            } catch {
                result.failed += 1
                result.failedPaths.append(expandedPath)
                result.lastError = error.localizedDescription
            }
        }

        if result.failed > 0 {
            let path = result.failedPaths.first.map { "：\($0)" } ?? ""
            engineMessage = "删除任务已完成，\(result.failed) 项未能移到废纸篓\(path)（\(result.lastError ?? "未知错误")）"
        }

        return result
    }

    private func resolvedDeletePath(_ path: String, task: DownloadTask) -> String {
        let expandedPath = (path as NSString).expandingTildeInPath
        guard !expandedPath.isEmpty else { return "" }
        guard !expandedPath.hasPrefix("/") else { return expandedPath }

        let expandedSavePath = (task.savePath as NSString).expandingTildeInPath
        guard !expandedSavePath.isEmpty else { return expandedPath }
        return URL(fileURLWithPath: expandedSavePath).appending(path: expandedPath).path
    }

    private func deleteHistoryResult(deleteFiles: Bool, trashResult: TrashResult?) -> String {
        guard deleteFiles else { return "已移除任务" }
        guard let trashResult, trashResult.total > 0 else { return "已移除任务，文件路径未知" }
        if trashResult.trashed == trashResult.total { return "已移到废纸篓" }
        if trashResult.trashed > 0 {
            return "已部分移到废纸篓（成功 \(trashResult.trashed)，失败 \(trashResult.failed)，未找到 \(trashResult.missing)）"
        }
        if trashResult.failed > 0 { return "已移除任务，\(trashResult.failed) 项删除失败" }
        return "已移除任务，\(trashResult.missing) 项文件未找到"
    }

    func addURLTask(urlText: String, fileName: String, splitCount: Int, downloadDirectory: String? = nil) async {
        let uris = urlText
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !uris.isEmpty else { return }

        var options = taskOptions(fileName: fileName, splitCount: splitCount, downloadDirectory: downloadDirectory)
        options["max-connection-per-server"] = "\(min(max(settings.maxConnectionsPerServer, 1), 64))"
        let containsMagnet = uris.contains { $0.lowercased().hasPrefix("magnet:") }
        if containsMagnet {
            options["pause"] = "true"
        }

        do {
            let client = makeClient()
            let gid = try await client.addUri(uris, options: options)
            selectedFilter = .all
            selectedTaskID = gid
            showAddTask = false
            if containsMagnet {
                try await prepareFileSelection(gid: gid, client: client)
            }
            await refreshTasksFromEngine()
        } catch {
            handleRPCError(error)
        }
    }

    func addTorrentTask(fileURL: URL, splitCount: Int, downloadDirectory: String? = nil) async {
        do {
            let data = try Data(contentsOf: fileURL)
            let client = makeClient()
            var options = taskOptions(fileName: "", splitCount: splitCount, downloadDirectory: downloadDirectory)
            options["pause"] = "true"
            let gid = try await client.addTorrent(
                data.base64EncodedString(),
                options: options
            )
            selectedFilter = .all
            selectedTaskID = gid
            showAddTask = false
            try await prepareFileSelection(gid: gid, client: client)
            await refreshTasksFromEngine()
        } catch {
            handleRPCError(error)
        }
    }

    func applyRuntimeDownloadSettings() async {
        guard connectionState == .connected else { return }

        do {
            _ = try await makeClient().changeGlobalOption([
                "max-concurrent-downloads": "\(min(max(settings.maxConcurrentDownloads, 1), 10))",
                "split": "\(min(max(settings.splitCount, 1), 64))",
                "max-connection-per-server": "\(min(max(settings.maxConnectionsPerServer, 1), 64))",
                "max-overall-download-limit": speedLimitOption(settings.downloadSpeedLimit) ?? "0",
                "max-overall-upload-limit": speedLimitOption(settings.uploadSpeedLimit) ?? "0"
            ])
        } catch {
            engineMessage = "设置已保存，但同步到 aria2 失败：\(error.localizedDescription)"
        }
    }

    func setPeerBlocklist(path: String) async {
        do {
            guard let validatedPath = try PeerBlocklistFile.validatedPath(path) else { return }
            if connectionState == .connected {
                _ = try await makeClient().changeGlobalOption([
                    "bt-peer-blocklist": validatedPath
                ])
                peerBlocklistMessage = "已加载 \(URL(fileURLWithPath: validatedPath).lastPathComponent)"
            } else {
                peerBlocklistMessage = "已保存，将在引擎连接时加载"
            }
            settings.btPeerBlocklistPath = validatedPath
        } catch {
            peerBlocklistMessage = error.localizedDescription
        }
    }

    func reloadPeerBlocklist() async {
        do {
            guard let validatedPath = try PeerBlocklistFile.validatedPath(settings.btPeerBlocklistPath) else {
                peerBlocklistMessage = "未配置"
                return
            }
            guard connectionState == .connected else {
                peerBlocklistMessage = "已保存，将在引擎连接时加载"
                return
            }

            _ = try await makeClient().changeGlobalOption([
                "bt-peer-blocklist": validatedPath
            ])
            peerBlocklistMessage = "已加载 \(URL(fileURLWithPath: validatedPath).lastPathComponent)"
        } catch {
            peerBlocklistMessage = "重新加载失败，当前规则保持不变：\(error.localizedDescription)"
        }
    }

    func clearPeerBlocklist() async {
        if connectionState == .connected {
            do {
                _ = try await makeClient().changeGlobalOption([
                    "bt-peer-blocklist": ""
                ])
            } catch {
                peerBlocklistMessage = "清除失败，当前规则仍然生效：\(error.localizedDescription)"
                return
            }
        }

        settings.btPeerBlocklistPath = ""
        peerBlocklistMessage = "未配置"
    }

    func startSelectedFilesDownload() async {
        guard let gid = pendingFileSelectionGID else {
            showFileSelection = false
            return
        }

        let selectedIndexes = fileCandidates
            .filter(\.isSelected)
            .map(\.aria2Index)
            .filter { !$0.isEmpty }
            .joined(separator: ",")
        guard !selectedIndexes.isEmpty else { return }

        do {
            let client = makeClient()
            _ = try await client.changeOption(gid: gid, options: ["select-file": selectedIndexes])
            _ = try await client.unpause(gid: gid)
            pendingFileSelectionGID = nil
            showFileSelection = false
            await refreshTasksFromEngine()
        } catch {
            handleRPCError(error)
        }
    }

    func cancelFileSelection() async {
        guard let gid = pendingFileSelectionGID else {
            showFileSelection = false
            return
        }

        do {
            _ = try await makeClient().forceRemove(gid: gid)
        } catch {
            handleRPCError(error)
        }
        pendingFileSelectionGID = nil
        showFileSelection = false
        await refreshTasksFromEngine()
    }

    private func updateSelectedStatus(_ status: TaskStatus) {
        guard let selectedTaskID, let index = tasks.firstIndex(where: { $0.id == selectedTaskID }) else { return }
        tasks[index].status = status
        if status == .active {
            tasks[index].downloadSpeed = "8.4 MB/s"
            tasks[index].remainingTime = "2m 04s"
        } else if status == .paused {
            tasks[index].downloadSpeed = "0 KB/s"
            tasks[index].remainingTime = "--"
        }
    }

    private func refreshTasksFromEngine(using client: Aria2Client) async throws {
        async let globalStat = client.getGlobalStat()
        async let active = client.tellActive()
        async let waiting = client.tellWaiting()
        async let stopped = client.tellStopped()

        let (stat, activeTasks, waitingTasks, stoppedTasks) = try await (globalStat, active, waiting, stopped)
        downloadSpeedText = Self.formatSpeed(stat.downloadSpeed)
        uploadSpeedText = Self.formatSpeed(stat.uploadSpeed)

        let previousSelection = selectedTaskID
        let refreshedTasks = (activeTasks + waitingTasks + stoppedTasks).map(Self.makeDownloadTask)
        notifyTaskChanges(refreshedTasks)
        tasks = refreshedTasks
        selectedTaskID = tasks.contains { $0.id == previousSelection } ? previousSelection : tasks.first?.id
        updateDockBadge()
    }

    private static func makeDownloadTask(from task: Aria2Task) -> DownloadTask {
        let totalBytes = int64(task.totalLength)
        let completedBytes = int64(task.completedLength)
        let downloadSpeedBytes = int64(task.downloadSpeed)
        let uploadSpeedBytes = int64(task.uploadSpeed)
        let fileNames = task.files?.compactMap { fileName(from: $0.path) }.filter { !$0.isEmpty } ?? []
        let sourceURLs = task.files?.flatMap { $0.uris ?? [] }.map(\.uri).reduce(into: [String]()) {
            if !$0.contains($1) {
                $0.append($1)
            }
        } ?? []
        let name = task.bittorrent?.info?.name ?? fileNames.first ?? task.gid
        let status = makeTaskStatus(from: task.status)

        return DownloadTask(
            name: name,
            protocolLabel: task.bittorrent == nil ? "RPC" : "BT",
            status: status,
            progress: totalBytes > 0 ? Double(completedBytes) / Double(totalBytes) : 0,
            completedSize: formatBytes(completedBytes),
            totalSize: formatBytes(totalBytes),
            downloadSpeed: formatSpeed(downloadSpeedBytes),
            uploadSpeed: formatSpeed(uploadSpeedBytes),
            remainingTime: remainingTime(total: totalBytes, completed: completedBytes, speed: downloadSpeedBytes, status: status),
            savePath: task.dir ?? "",
            gid: task.gid,
            detail: "来自 aria2 JSON-RPC 的任务。",
            errorMessage: task.errorMessage,
            fileNames: fileNames.isEmpty ? [name] : fileNames,
            localFilePaths: task.files?.map(\.path).filter { !$0.isEmpty } ?? [],
            sourceURLs: sourceURLs,
            infoHash: task.bittorrent?.infoHash,
            ed2kHash: nil
        )
    }

    private static func makeTaskStatus(from status: String) -> TaskStatus {
        switch status {
        case "active": .active
        case "waiting": .waiting
        case "paused": .paused
        case "complete": .complete
        case "error", "removed": .failed
        default: .waiting
        }
    }

    private static func int64(_ value: String?) -> Int64 {
        Int64(value ?? "") ?? 0
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private static func formatSpeed(_ bytesPerSecond: String?) -> String {
        formatSpeed(int64(bytesPerSecond))
    }

    private static func formatSpeed(_ bytesPerSecond: Int64) -> String {
        "\(formatBytes(bytesPerSecond))/s"
    }

    private static func remainingTime(total: Int64, completed: Int64, speed: Int64, status: TaskStatus) -> String {
        if status == .complete { return "已完成" }
        guard total > completed, speed > 0 else { return "--" }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval((total - completed) / speed)) ?? "--"
    }

    private static func fileName(from path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    private static func currentTimeText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }

    private func prepareFileSelection(gid: String, client: Aria2Client) async throws {
        engineMessage = "等待 BT/magnet 文件列表"
        let files = try await waitForFiles(gid: gid, client: client)
        guard !files.isEmpty else { return }

        pendingFileSelectionGID = gid
        fileCandidates = files.map {
            FileCandidate(
                aria2Index: $0.index,
                name: Self.fileName(from: $0.path).isEmpty ? "文件 \($0.index)" : Self.fileName(from: $0.path),
                size: Self.formatBytes(Self.int64($0.length)),
                isSelected: $0.selected != "false"
            )
        }
        showFileSelection = true
    }

    private func waitForFiles(gid: String, client: Aria2Client) async throws -> [Aria2File] {
        var lastFiles: [Aria2File] = []
        for _ in 0..<30 {
            lastFiles = try await client.getFiles(gid: gid)
            if !lastFiles.isEmpty {
                return lastFiles
            }
            try await Task.sleep(for: .seconds(1))
        }
        return lastFiles
    }

    private func connectOrStartEngine(client: Aria2Client) async throws -> Aria2Version {
        if engineManager.isRunning {
            if activeRPCPort == settings.rpcPort, activeRPCToken == rpcSecret {
                return try await waitForEngine(client: client)
            }

            engineMessage = "正在重启 aria2 引擎以应用新的 RPC 设置"
            _ = try? await client.saveSession()
            _ = try await client.forceShutdown()
            try await waitForExternalEngineToStop(client: client)
            try await waitForManagedEngineToStop()
            engineManager.stop()
        }

        if let _ = try? await client.getVersion() {
            engineMessage = "正在重启旧 aria2 引擎以应用 TLS 设置"
            _ = try? await client.saveSession()
            _ = try await client.forceShutdown()
            try await waitForExternalEngineToStop(client: client)
            try await Task.sleep(for: .seconds(1))
        } else {
            let noSecretClient = Aria2Client(port: settings.rpcPort)
            if await noSecretClient.isReachable() {
                throw EngineManagerError.externalRPCInUse(settings.rpcPort)
            }
        }

        activeRPCPort = settings.rpcPort
        activeRPCToken = rpcSecret
        let launchClient = makeClient()
        engineMessage = "正在启动 aria2 引擎"
        try engineManager.startIfNeeded(settings: settings, rpcSecret: rpcSecret)
        return try await waitForEngine(client: launchClient)
    }

    private func waitForEngine(client: Aria2Client) async throws -> Aria2Version {
        var lastError: Error?
        for _ in 0..<20 {
            do {
                return try await client.getVersion()
            } catch {
                lastError = error
                if !engineManager.isRunning {
                    throw EngineManagerError.processExited(engineManager.recentLogTail())
                }
                try await Task.sleep(for: .milliseconds(250))
            }
        }

        let logTail = engineManager.recentLogTail()
        if !logTail.isEmpty {
            throw EngineManagerError.rpcUnavailable(logTail)
        }

        throw lastError ?? EngineManagerError.executableNotFound
    }

    private func waitForExternalEngineToStop(client: Aria2Client) async throws {
        for _ in 0..<24 {
            do {
                _ = try await client.getVersion()
            } catch {
                return
            }
            try await Task.sleep(for: .milliseconds(250))
        }

        throw EngineManagerError.rpcUnavailable("旧 aria2 引擎未释放 RPC 端口 \(settings.rpcPort)。")
    }

    private func waitForManagedEngineToStop() async throws {
        for _ in 0..<50 {
            if !engineManager.isRunning {
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        let port = activeRPCPort ?? settings.rpcPort
        throw EngineManagerError.rpcUnavailable("旧 aria2 引擎进程未完全退出，RPC 端口 \(port) 尚未释放。")
    }

    private func handleRPCError(_ error: Error) {
        engineMessage = error.localizedDescription
        guard !(error is Aria2RPCError) else { return }
        connectionState = .failed
        stopPolling()
    }

    private func notifyTaskChanges(_ refreshedTasks: [DownloadTask]) {
        defer {
            knownTaskStatuses = Dictionary(uniqueKeysWithValues: refreshedTasks.map { ($0.gid, $0.status) })
        }

        guard !knownTaskStatuses.isEmpty else { return }

        for task in refreshedTasks {
            let previousStatus = knownTaskStatuses[task.gid]
            guard previousStatus != task.status else { continue }

            if task.status == .complete {
                notificationService.send(title: "下载完成", body: task.name)
            } else if task.status == .failed {
                notificationService.send(title: "下载失败", body: task.name)
            } else if task.status == .active {
                notificationService.send(title: "任务开始", body: task.name)
            }

            if task.status == .complete {
                addHistoryItem(
                    HistoryItem(
                        gid: task.gid,
                        name: task.name,
                        result: "已完成",
                        finishedAt: Self.currentTimeText(),
                        location: task.savePath
                    )
                )
            } else if task.status == .failed {
                addHistoryItem(
                    HistoryItem(
                        gid: task.gid,
                        name: task.name,
                        result: "已失败",
                        finishedAt: Self.currentTimeText(),
                        location: task.errorMessage ?? task.savePath
                    )
                )
            }
        }
    }

    private func updateDockBadge() {
        dockService.update(activeCount: activeCount, progress: activeCount > 0 ? activeProgress : nil)
    }

    private func makeClient() -> Aria2Client {
        Aria2Client(port: activeRPCPort ?? settings.rpcPort, token: activeRPCToken)
    }

    private func sortedTasks(_ tasks: [DownloadTask]) -> [DownloadTask] {
        switch taskSort {
        case .status:
            tasks.sorted { lhs, rhs in
                let lhsRank = statusRank(lhs.status)
                let rhsRank = statusRank(rhs.status)
                return lhsRank == rhsRank ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending : lhsRank < rhsRank
            }
        case .name:
            tasks.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .progress:
            tasks.sorted { $0.progress > $1.progress }
        }
    }

    private func statusRank(_ status: TaskStatus) -> Int {
        switch status {
        case .active: 0
        case .waiting: 1
        case .paused: 2
        case .failed: 3
        case .complete: 4
        }
    }

    private func taskOptions(fileName: String, splitCount: Int, downloadDirectory: String? = nil) -> [String: String] {
        let directory = resolvedDownloadDirectory(downloadDirectory)
        let normalizedSplitCount = min(max(splitCount, 1), 64)
        var options: [String: String] = [
            "dir": directory,
            "split": "\(normalizedSplitCount)"
        ]

        let trimmedFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFileName.isEmpty {
            options["out"] = trimmedFileName
        }

        if let downloadLimit = speedLimitOption(settings.downloadSpeedLimit) {
            options["max-download-limit"] = downloadLimit
        }

        if let uploadLimit = speedLimitOption(settings.uploadSpeedLimit) {
            options["max-upload-limit"] = uploadLimit
        }

        return options
    }

    private func resolvedDownloadDirectory(_ downloadDirectory: String?) -> String {
        let trimmedDirectory = downloadDirectory?.trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = trimmedDirectory?.isEmpty == false ? trimmedDirectory! : settings.downloadDirectory
        let expandedDirectory = (directory as NSString).expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: expandedDirectory, withIntermediateDirectories: true)
        return expandedDirectory
    }

    private func speedLimitOption(_ value: Int) -> String? {
        value > 0 ? "\(value)M" : nil
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                await self?.refreshTasksFromEngine()
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
