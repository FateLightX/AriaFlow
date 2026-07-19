import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
    @State private var peerBlocklistURLDraft = ""

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
                .scrollDisabled(true)
                .contentMargins(.top, 8, for: .scrollContent)
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .contentMargins(.bottom, 8, for: .scrollContent)
                .frame(maxWidth: .infinity, alignment: .top)
                .fixedSize(horizontal: false, vertical: true)
                .tabItem {
                    Label(category.title, systemImage: category.symbol)
                }
                .tag(category)
            }
        }
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            peerBlocklistURLDraft = PeerBlocklistFile.displayString(forURLString: store.settings.btPeerBlocklistURL)
        }
        .onChange(of: store.settings.btPeerBlocklistURL) {
            peerBlocklistURLDraft = PeerBlocklistFile.displayString(forURLString: store.settings.btPeerBlocklistURL)
        }
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
                toggleRow("隐藏 Dock 图标", isOn: hideDockIconBinding)
                    .disabled(!canRunInMenuBar)
                Text("开启后不出现在 Dock，主窗口与设置仍可打开。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                subtitle: "填写规则列表链接（http/https）。下载后按文本格式校验：每行一个 IPv4、IPv6 或 CIDR，空行和 # 注释会被忽略。",
                symbol: "shield.lefthalf.filled"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("规则链接")
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 8) {
                            TextField("", text: $peerBlocklistURLDraft)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color(nsColor: .textBackgroundColor))
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(store.peerBlocklistBusy)
                                .onSubmit {
                                    applyPeerBlocklistURL()
                                }

                            Button(store.settings.btPeerBlocklistURL.isEmpty ? "添加" : "更新") {
                                applyPeerBlocklistURL()
                            }
                            .controlSize(.small)
                            .fixedSize()
                            .disabled(store.peerBlocklistBusy || peerBlocklistURLDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !store.settings.btPeerBlocklistURL.isEmpty {
                        pathValue(PeerBlocklistFile.displayString(forURLString: store.settings.btPeerBlocklistURL))
                    }

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
                        .disabled(store.peerBlocklistBusy || store.settings.btPeerBlocklistURL.isEmpty)

                        Button("清除") {
                            Task {
                                await store.clearPeerBlocklist()
                                peerBlocklistURLDraft = ""
                            }
                        }
                        .disabled(store.peerBlocklistBusy || store.settings.btPeerBlocklistURL.isEmpty)
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
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.2"
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
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private func applyPeerBlocklistURL() {
        let draft = peerBlocklistURLDraft
        Task {
            await store.setPeerBlocklist(urlString: draft)
            peerBlocklistURLDraft = PeerBlocklistFile.displayString(forURLString: store.settings.btPeerBlocklistURL)
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
