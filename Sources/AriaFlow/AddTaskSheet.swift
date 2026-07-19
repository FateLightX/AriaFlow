import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
