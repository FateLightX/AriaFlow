import Darwin
import Foundation

enum PeerBlocklistFileError: LocalizedError {
    case unavailable(String)
    case unreadable(String)
    case invalidRule(line: Int, value: String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let path):
            "Peer Blocklist 文件不存在或不可读：\(path)"
        case .unreadable(let path):
            "无法读取 Peer Blocklist 文件：\(path)"
        case .invalidRule(let line, let value):
            "Peer Blocklist 第 \(line) 行不是有效的 IP 或 CIDR：\(value)"
        }
    }
}

enum PeerBlocklistFile {
    static func validatedPath(_ rawPath: String) throws -> String? {
        let trimmedPath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }

        let path = URL(fileURLWithPath: (trimmedPath as NSString).expandingTildeInPath)
            .standardizedFileURL.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              FileManager.default.isReadableFile(atPath: path) else {
            throw PeerBlocklistFileError.unavailable(path)
        }

        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw PeerBlocklistFileError.unreadable(path)
        }

        for (index, rawLine) in contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let rule = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rule.isEmpty, !rule.hasPrefix("#") else { continue }
            guard isValidRule(rule) else {
                throw PeerBlocklistFileError.invalidRule(line: index + 1, value: rule)
            }
        }

        return path
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
           let blocklistPath = try? PeerBlocklistFile.validatedPath(settings.btPeerBlocklistPath) {
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
