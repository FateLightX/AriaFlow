import AppKit
import CryptoKit
import Foundation
import Network

@MainActor
final class SoftwareUpdater: ObservableObject {
    struct Configuration: Sendable {
        let appName: String
        let bundleIdentifier: String
        let repository: String
        let fallbackVersion: String

        static let ariaFlow = Configuration(
            appName: "AriaFlow",
            bundleIdentifier: "com.ariaflow.desktop",
            repository: "FateLightX/AriaFlow",
            fallbackVersion: "0.3.4"
        )
    }

    @Published private(set) var statusText = "等待检查更新"
    @Published private(set) var isBusy = false

    private let configuration: Configuration
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.ariaflow.desktop.software-updater")
    private var periodicTask: Task<Void, Never>?
    private var started = false
    private var networkAvailable = false

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    func start() {
        guard !started else { return }
        started = true

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasAvailable = networkAvailable
                networkAvailable = path.status == .satisfied
                if networkAvailable && !wasAvailable {
                    await checkAndInstallIfAvailable()
                }
            }
        }
        monitor.start(queue: monitorQueue)

        periodicTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(21_600))
                guard let self, networkAvailable else { continue }
                await checkAndInstallIfAvailable()
            }
        }
    }

    func checkNow() {
        Task {
            await checkAndInstallIfAvailable()
        }
    }

    nonisolated static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let candidateParts = versionParts(candidate)
        let currentParts = versionParts(current)
        let count = max(candidateParts.count, currentParts.count)
        for index in 0..<count {
            let lhs = index < candidateParts.count ? candidateParts[index] : 0
            let rhs = index < currentParts.count ? currentParts[index] : 0
            if lhs != rhs { return lhs > rhs }
        }
        return false
    }

    private func checkAndInstallIfAvailable() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            statusText = "正在检查更新…"
            let release = try await latestRelease()
            let latestVersion = Self.normalizedVersion(release.tagName)
            let currentVersion = Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? configuration.fallbackVersion

            guard Self.isVersion(latestVersion, newerThan: currentVersion) else {
                statusText = "已是最新版本 \(currentVersion)"
                return
            }

            let assets = try selectAssets(in: release, version: latestVersion)
            statusText = "正在下载 \(latestVersion)…"
            let updateDirectory = FileManager.default.temporaryDirectory
                .appending(path: "\(configuration.appName)-update-\(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: updateDirectory, withIntermediateDirectories: true)

            do {
                let archiveURL = updateDirectory.appending(path: assets.archive.name)
                let checksumURL = updateDirectory.appending(path: assets.checksum.name)
                try await download(assets.archive, to: archiveURL)
                try await download(assets.checksum, to: checksumURL)

                statusText = "正在验证更新…"
                try await verifyChecksum(archiveURL: archiveURL, checksumURL: checksumURL, digest: assets.archive.digest)
                let stagedApp = try await stageAndVerifyApp(
                    archiveURL: archiveURL,
                    in: updateDirectory,
                    expectedVersion: latestVersion
                )

                statusText = "正在安装并重新启动…"
                try launchInstaller(stagedApp: stagedApp, updateDirectory: updateDirectory)
            } catch {
                try? FileManager.default.removeItem(at: updateDirectory)
                throw error
            }
        } catch {
            statusText = "更新失败：\(error.localizedDescription)"
        }
    }

    private func latestRelease() async throws -> GitHubRelease {
        do {
            return try await githubLatestRelease()
        } catch {
            statusText = "GitHub 检查失败，正在尝试加速线路…"
            return try await jsDelivrLatestRelease()
        }
    }

    private func githubLatestRelease() async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(configuration.repository)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("\(configuration.appName)-Updater", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.requireSuccessfulResponse(response)
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard !release.draft, !release.prerelease else { throw UpdateError.noStableRelease }
        return release
    }

    private func jsDelivrLatestRelease() async throws -> GitHubRelease {
        let url = URL(string: "https://fastly.jsdelivr.net/gh/\(configuration.repository)@main/update.json")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("\(configuration.appName)-Updater", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.requireSuccessfulResponse(response)
        let manifest = try JSONDecoder().decode(UpdateManifest.self, from: data)
        return try fallbackRelease(version: manifest.version)
    }

    private func fallbackRelease(version: String) throws -> GitHubRelease {
        let normalizedVersion = Self.normalizedVersion(version)
        guard !normalizedVersion.isEmpty else { throw UpdateError.invalidManifest }
        let tagName = "v\(normalizedVersion)"
        guard let baseURL = URL(
            string: "https://github.com/\(configuration.repository)/releases/download/\(tagName)/"
        ) else {
            throw UpdateError.invalidManifest
        }
        let archiveNames = [
            "\(configuration.appName)-\(normalizedVersion)-arm64.zip",
            "\(configuration.appName)-\(normalizedVersion)-x86_64.zip",
            "\(configuration.appName)-\(normalizedVersion).zip"
        ]
        let assets = archiveNames.flatMap { name -> [GitHubAsset] in
            [
                GitHubAsset(name: name, downloadURL: baseURL.appending(path: name), digest: nil),
                GitHubAsset(name: "\(name).sha256", downloadURL: baseURL.appending(path: "\(name).sha256"), digest: nil)
            ]
        }
        return GitHubRelease(tagName: tagName, draft: false, prerelease: false, assets: assets)
    }

    private func selectAssets(in release: GitHubRelease, version: String) throws -> SelectedAssets {
        let architecture = Self.currentArchitecture
        let archiveNames = [
            "\(configuration.appName)-\(version)-\(architecture).zip",
            "\(configuration.appName)-\(version).zip"
        ]
        guard let archive = archiveNames.lazy.compactMap({ name in
            release.assets.first { $0.name == name }
        }).first else {
            throw UpdateError.missingAsset(archiveNames.joined(separator: " 或 "))
        }
        guard let checksum = release.assets.first(where: { $0.name == "\(archive.name).sha256" }) else {
            throw UpdateError.missingAsset("\(archive.name).sha256")
        }
        return SelectedAssets(archive: archive, checksum: checksum)
    }

    private func download(_ asset: GitHubAsset, to destination: URL) async throws {
        var request = URLRequest(url: asset.downloadURL)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue("\(configuration.appName)-Updater", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 120
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        try Self.requireSuccessfulResponse(response)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
    }

    private func verifyChecksum(archiveURL: URL, checksumURL: URL, digest: String?) async throws {
        let checksumText = try String(contentsOf: checksumURL, encoding: .utf8)
        guard let expected = checksumText
            .split(whereSeparator: { $0.isWhitespace })
            .first
            .map(String.init), expected.count == 64 else {
            throw UpdateError.invalidChecksumFile
        }
        let actual = try await Task.detached {
            let data = try Data(contentsOf: archiveURL)
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }.value
        guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
            throw UpdateError.checksumMismatch
        }
        if let digest, digest.hasPrefix("sha256:") {
            let apiDigest = String(digest.dropFirst("sha256:".count))
            guard actual.caseInsensitiveCompare(apiDigest) == .orderedSame else {
                throw UpdateError.checksumMismatch
            }
        }
    }

    private func stageAndVerifyApp(
        archiveURL: URL,
        in updateDirectory: URL,
        expectedVersion: String
    ) async throws -> URL {
        let extractionURL = updateDirectory.appending(path: "extracted", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: extractionURL, withIntermediateDirectories: true)
        try await Self.run("/usr/bin/ditto", arguments: ["-x", "-k", archiveURL.path, extractionURL.path])

        guard let appURL = Self.firstApp(in: extractionURL), let bundle = Bundle(url: appURL) else {
            throw UpdateError.invalidApplication
        }
        guard bundle.bundleIdentifier == configuration.bundleIdentifier else {
            throw UpdateError.bundleIdentifierMismatch
        }
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard version == expectedVersion else { throw UpdateError.versionMismatch }
        guard let executableURL = bundle.executableURL else { throw UpdateError.invalidApplication }

        try await Self.run("/usr/bin/codesign", arguments: ["--verify", "--deep", "--strict", appURL.path])
        let architectures = try await Self.output("/usr/bin/lipo", arguments: ["-archs", executableURL.path])
        guard architectures.split(whereSeparator: { $0.isWhitespace }).contains(Substring(Self.currentArchitecture)) else {
            throw UpdateError.architectureMismatch
        }
        return appURL
    }

    private func launchInstaller(stagedApp: URL, updateDirectory: URL) throws {
        let currentApp = Bundle.main.bundleURL.standardizedFileURL
        guard currentApp.pathExtension == "app" else { throw UpdateError.notRunningFromApplication }
        let parent = currentApp.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            throw UpdateError.installLocationNotWritable
        }

        let installerURL = updateDirectory.appending(path: "install-update.zsh")
        let script = """
        #!/bin/zsh
        set -eu
        current_app="$1"
        staged_app="$2"
        app_pid="$3"
        update_dir="$4"
        backup_app="$current_app.update-backup"
        new_app="$current_app.update-new"
        /bin/rm -rf "$new_app" "$backup_app"
        /usr/bin/ditto "$staged_app" "$new_app"
        while /bin/kill -0 "$app_pid" 2>/dev/null; do /bin/sleep 0.2; done
        if ! /bin/mv "$current_app" "$backup_app"; then
          /bin/rm -rf "$new_app"
          exit 1
        fi
        if /bin/mv "$new_app" "$current_app"; then
          /usr/bin/open "$current_app"
          /bin/rm -rf "$backup_app" "$update_dir"
        else
          /bin/mv "$backup_app" "$current_app" 2>/dev/null || true
          /usr/bin/open "$current_app" 2>/dev/null || true
          exit 1
        fi
        """
        try Data(script.utf8).write(to: installerURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: installerURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [
            installerURL.path,
            currentApp.path,
            stagedApp.path,
            String(ProcessInfo.processInfo.processIdentifier),
            updateDirectory.path
        ]
        try process.run()
        NSApp.terminate(nil)
    }

    private static var currentArchitecture: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unsupported"
        #endif
    }

    nonisolated private static func normalizedVersion(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    nonisolated private static func versionParts(_ value: String) -> [Int] {
        normalizedVersion(value).split(separator: ".").map { part in
            Int(part.prefix(while: { $0.isNumber })) ?? 0
        }
    }

    private static func requireSuccessfulResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw UpdateError.invalidResponse
        }
    }

    private static func firstApp(in directory: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for case let url as URL in enumerator where url.pathExtension == "app" {
            return url
        }
        return nil
    }

    private static func run(_ executable: String, arguments: [String]) async throws {
        _ = try await execute(executable, arguments: arguments, captureOutput: false)
    }

    private static func output(_ executable: String, arguments: [String]) async throws -> String {
        try await execute(executable, arguments: arguments, captureOutput: true)
    }

    private static func execute(
        _ executable: String,
        arguments: [String],
        captureOutput: Bool
    ) async throws -> String {
        try await Task.detached {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            if captureOutput {
                process.standardOutput = pipe
            }
            process.standardError = Pipe()
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw UpdateError.commandFailed(executable) }
            guard captureOutput else { return "" }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(decoding: data, as: UTF8.self)
        }.value
    }
}

private struct GitHubRelease: Decodable, Sendable {
    let tagName: String
    let draft: Bool
    let prerelease: Bool
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case draft
        case prerelease
        case assets
    }
}

private struct UpdateManifest: Decodable, Sendable {
    let version: String
}

private struct GitHubAsset: Decodable, Sendable {
    let name: String
    let downloadURL: URL
    let digest: String?

    enum CodingKeys: String, CodingKey {
        case name
        case downloadURL = "browser_download_url"
        case digest
    }
}

private struct SelectedAssets: Sendable {
    let archive: GitHubAsset
    let checksum: GitHubAsset
}

private enum UpdateError: LocalizedError {
    case noStableRelease
    case missingAsset(String)
    case invalidResponse
    case invalidManifest
    case invalidChecksumFile
    case checksumMismatch
    case invalidApplication
    case bundleIdentifierMismatch
    case versionMismatch
    case architectureMismatch
    case commandFailed(String)
    case notRunningFromApplication
    case installLocationNotWritable

    var errorDescription: String? {
        switch self {
        case .noStableRelease: "没有可用的稳定版本"
        case let .missingAsset(name): "Release 缺少文件：\(name)"
        case .invalidResponse: "服务器响应无效"
        case .invalidManifest: "更新清单无效"
        case .invalidChecksumFile: "SHA256 校验文件无效"
        case .checksumMismatch: "下载文件的 SHA256 不匹配"
        case .invalidApplication: "更新包中没有有效的 App"
        case .bundleIdentifierMismatch: "更新包的应用标识不匹配"
        case .versionMismatch: "更新包的版本不匹配"
        case .architectureMismatch: "更新包不支持当前处理器"
        case let .commandFailed(command): "验证命令失败：\(command)"
        case .notRunningFromApplication: "当前不是从 App 包运行，无法自动安装"
        case .installLocationNotWritable: "当前安装目录不可写，请手动更新"
        }
    }
}
