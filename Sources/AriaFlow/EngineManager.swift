import Darwin
import Foundation

enum PeerBlocklistFileError: LocalizedError {
    case unavailable(String)
    case unreadable(String)
    case invalidRule(line: Int, value: String)
    case invalidURL(String)
    case unsupportedScheme(String)
    case downloadFailed(String)
    case emptyContent
    case tooLarge(Int)

    var errorDescription: String? {
        switch self {
        case .unavailable(let path):
            "Peer Blocklist 缓存不可读：\(path)"
        case .unreadable(let path):
            "无法读取 Peer Blocklist：\(path)"
        case .invalidRule(let line, let value):
            "Peer Blocklist 第 \(line) 行不是有效的 IP 或 CIDR：\(value)"
        case .invalidURL(let value):
            "Peer Blocklist 链接无效：\(value)"
        case .unsupportedScheme(let scheme):
            "Peer Blocklist 仅支持 http 或 https 链接，当前为：\(scheme)"
        case .downloadFailed(let detail):
            "Peer Blocklist 下载失败：\(detail)"
        case .emptyContent:
            "Peer Blocklist 内容为空"
        case .tooLarge(let limit):
            "Peer Blocklist 超过大小限制（\(limit) 字节）"
        }
    }
}

enum PeerBlocklistFile {
    static let maxDownloadBytes = 10 * 1024 * 1024

    static func normalizedURLString(_ raw: String) throws -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), !scheme.isEmpty else {
            throw PeerBlocklistFileError.invalidURL(trimmed)
        }

        guard scheme == "http" || scheme == "https" else {
            throw PeerBlocklistFileError.unsupportedScheme(scheme)
        }
        guard let host = url.host, !host.isEmpty else {
            throw PeerBlocklistFileError.invalidURL(trimmed)
        }
        return url.absoluteString
    }

    static func displayString(forURLString raw: String) -> String {
        (try? normalizedURLString(raw)) ?? raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns the validated local cache path when a remote URL is configured and the cache is present.
    static func resolvedLocalPath(
        forURLString raw: String,
        cacheURL: URL = LocalAppFiles.peerBlocklistCacheURL
    ) throws -> String? {
        guard try normalizedURLString(raw) != nil else { return nil }
        return try validatedCachePath(cacheURL)
    }

    /// Downloads an http(s) list into the cache (atomically) and returns the source URL plus cache path.
    static func materialize(
        fromURLString raw: String,
        cacheURL: URL = LocalAppFiles.peerBlocklistCacheURL
    ) async throws -> (sourceURL: String, localPath: String) {
        guard let normalized = try normalizedURLString(raw),
              let url = URL(string: normalized) else {
            throw PeerBlocklistFileError.invalidURL(raw)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw PeerBlocklistFileError.downloadFailed(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw PeerBlocklistFileError.downloadFailed("HTTP \(http.statusCode)")
        }
        guard !data.isEmpty else {
            throw PeerBlocklistFileError.emptyContent
        }
        guard data.count <= maxDownloadBytes else {
            throw PeerBlocklistFileError.tooLarge(maxDownloadBytes)
        }

        guard let contents = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw PeerBlocklistFileError.unreadable(url.absoluteString)
        }

        let path = try installValidatedCache(contents: contents, cacheURL: cacheURL)
        return (normalized, path)
    }

    static func installValidatedCache(
        contents: String,
        cacheURL: URL = LocalAppFiles.peerBlocklistCacheURL
    ) throws -> String {
        try validateContents(contents)

        LocalAppFiles.ensureDirectory()
        let temporaryURL = cacheURL.deletingLastPathComponent()
            .appending(path: cacheURL.lastPathComponent + ".download")
        if FileManager.default.fileExists(atPath: temporaryURL.path) {
            try FileManager.default.removeItem(at: temporaryURL)
        }
        try contents.write(to: temporaryURL, atomically: true, encoding: .utf8)

        do {
            _ = try validatedCachePath(temporaryURL)
            if FileManager.default.fileExists(atPath: cacheURL.path) {
                _ = try FileManager.default.replaceItemAt(cacheURL, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: cacheURL)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }

        return try validatedCachePath(cacheURL)
    }

    static func validatedCachePath(_ cacheURL: URL) throws -> String {
        let path = cacheURL.standardizedFileURL.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              FileManager.default.isReadableFile(atPath: path) else {
            throw PeerBlocklistFileError.unavailable(path)
        }

        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw PeerBlocklistFileError.unreadable(path)
        }

        try validateContents(contents)
        return path
    }

    static func validateContents(_ contents: String) throws {
        var sawRule = false
        for (index, rawLine) in contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let rule = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rule.isEmpty, !rule.hasPrefix("#") else { continue }
            guard isValidRule(rule) else {
                throw PeerBlocklistFileError.invalidRule(line: index + 1, value: rule)
            }
            sawRule = true
        }
        if !sawRule {
            throw PeerBlocklistFileError.emptyContent
        }
    }

    private static func isValidRule(_ rule: String) -> Bool {
        let components = rule.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 1 || components.count == 2 else { return false }

        let address = String(components[0])
        let maxPrefixLength: Int
        var ipv4Address = in_addr()
        var ipv6Address = in6_addr()

        if address.withCString({ inet_pton(AF_INET, $0, &ipv4Address) }) == 1 {
            maxPrefixLength = 32
        } else if address.withCString({ inet_pton(AF_INET6, $0, &ipv6Address) }) == 1 {
            maxPrefixLength = 128
        } else {
            return false
        }

        guard components.count == 2 else { return true }
        guard let prefixLength = Int(components[1]),
              (0...maxPrefixLength).contains(prefixLength) else {
            return false
        }
        return true
    }
}

enum EngineManagerError: Error, LocalizedError {
    case executableNotFound
    case processExited(String)
    case rpcUnavailable(String)
    case externalRPCInUse(Int)

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            "找不到 aria2 可执行文件。请先安装 aria2，或将 aria2c/aria2-next 放入应用资源目录。"
        case .processExited(let logTail):
            logTail.isEmpty ? "aria2 引擎启动后立即退出。" : "aria2 引擎启动后立即退出：\(logTail)"
        case .rpcUnavailable(let logTail):
            logTail.isEmpty ? "aria2 引擎已启动，但 RPC 暂不可用。" : "aria2 引擎已启动，但 RPC 暂不可用：\(logTail)"
        case .externalRPCInUse(let port):
            "RPC 端口 \(port) 已被外部 aria2 占用。请关闭该进程，或修改 AriaFlow 的 RPC 端口后重试。"
        }
    }
}

final class EngineManager {
    private var process: Process?

    var isRunning: Bool {
        process?.isRunning == true
    }

    func startIfNeeded(settings: AppSettings, rpcSecret: String) throws {
        guard process?.isRunning != true else { return }
        guard let executableURL = Self.findExecutable() else {
            throw EngineManagerError.executableNotFound
        }

        LocalAppFiles.ensureDirectory()
        if !FileManager.default.fileExists(atPath: LocalAppFiles.sessionURL.path) {
            FileManager.default.createFile(atPath: LocalAppFiles.sessionURL.path, contents: nil)
        }
        let downloadDirectory = (settings.downloadDirectory as NSString).expandingTildeInPath
        try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = executableURL
        var arguments = [
            "--enable-rpc=true",
            "--rpc-listen-all=false",
            "--rpc-listen-port=\(settings.rpcPort)",
            "--dir=\(downloadDirectory)",
            "--max-concurrent-downloads=\(min(max(settings.maxConcurrentDownloads, 1), 10))",
            "--split=\(min(max(settings.splitCount, 1), 64))",
            "--max-connection-per-server=\(min(max(settings.maxConnectionsPerServer, 1), 64))",
            "--check-certificate=false",
            "--input-file=\(LocalAppFiles.sessionURL.path)",
            "--save-session=\(LocalAppFiles.sessionURL.path)",
            "--save-session-interval=30",
            "--log=\(LocalAppFiles.logURL.path)",
            "--log-level=info"
        ]

        if Self.isBundledExecutable(executableURL),
           let blocklistPath = try? PeerBlocklistFile.resolvedLocalPath(forURLString: settings.btPeerBlocklistURL) {
            arguments.append("--bt-peer-blocklist=\(blocklistPath)")
        }

        if !rpcSecret.isEmpty {
            arguments.append("--rpc-secret=\(rpcSecret)")
        }

        if let downloadLimit = Self.speedLimitArgument(settings.downloadSpeedLimit) {
            arguments.append("--max-overall-download-limit=\(downloadLimit)")
        }

        if let uploadLimit = Self.speedLimitArgument(settings.uploadSpeedLimit) {
            arguments.append("--max-overall-upload-limit=\(uploadLimit)")
        }

        if let configURL = Self.bundledConfigURL {
            arguments.append("--conf-path=\(configURL.path)")
        }

        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        self.process = process
    }

    func stop() {
        process?.terminate()
        process = nil
    }

    func recentLogTail(lineLimit: Int = 6) -> String {
        guard let text = try? String(contentsOf: LocalAppFiles.logURL, encoding: .utf8) else { return "" }
        return text
            .split(separator: "\n")
            .suffix(lineLimit)
            .joined(separator: " ")
    }

    private static func findExecutable() -> URL? {
        findBundledExecutable() ?? findSystemExecutable()
    }

    private static func findBundledExecutable() -> URL? {
        let bundleCandidates = bundledExecutableNames.flatMap { name in
            [
                Bundle.main.resourceURL?.appending(path: name),
                Bundle.main.resourceURL?.appending(path: "Resources/\(name)"),
                Bundle.main.bundleURL.appending(path: "AriaFlow_AriaFlow.bundle/Resources/\(name)")
            ]
        }

        return bundleCandidates.compactMap { $0 }.first(where: isExecutable)
    }

    private static func findSystemExecutable() -> URL? {
        let pathCandidates = [
            "/opt/homebrew/bin/aria2c",
            "/usr/local/bin/aria2c",
            "/usr/bin/aria2c",
            "/opt/homebrew/bin/aria2-next",
            "/usr/local/bin/aria2-next"
        ].map(URL.init(fileURLWithPath:))

        return pathCandidates.first(where: isExecutable)
    }

    private static var bundledExecutableNames: [String] {
        #if arch(arm64)
        ["motrix-next-engine-aarch64-apple-darwin", "aria2-next", "aria2c"]
        #elseif arch(x86_64)
        ["motrix-next-engine-x86_64-apple-darwin", "aria2-next", "aria2c"]
        #else
        ["aria2-next", "aria2c"]
        #endif
    }

    static var bundledConfigURL: URL? {
        [
            Bundle.main.resourceURL?.appending(path: "aria2.conf"),
            Bundle.main.resourceURL?.appending(path: "Resources/aria2.conf"),
            Bundle.main.bundleURL.appending(path: "AriaFlow_AriaFlow.bundle/Resources/aria2.conf")
        ]
        .compactMap { $0 }
        .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func isExecutable(_ url: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: url.path)
    }

    private static func isBundledExecutable(_ url: URL) -> Bool {
        guard let resourcePath = Bundle.main.resourceURL?.standardizedFileURL.path else { return false }
        return url.standardizedFileURL.path.hasPrefix(resourcePath + "/")
    }

    private static func speedLimitArgument(_ value: Int) -> String? {
        value > 0 ? "\(value)M" : nil
    }
}
