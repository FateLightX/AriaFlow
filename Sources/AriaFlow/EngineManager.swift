import Foundation

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
            "--log-level=notice"
        ]

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

    private static func speedLimitArgument(_ value: Int) -> String? {
        value > 0 ? "\(value)M" : nil
    }
}
