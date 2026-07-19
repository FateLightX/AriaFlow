import Foundation

enum SmokeDownloadRunner {
    static func runIfRequested() -> Never? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--smoke-download") else { return nil }
        guard arguments.count >= index + 4 else {
            fputs("usage: AriaFlow --smoke-download URL DOWNLOAD_DIR RPC_PORT\n", stderr)
            exit(2)
        }

        let url = arguments[index + 1]
        let downloadDirectory = arguments[index + 2]
        guard let rpcPort = Int(arguments[index + 3]) else {
            fputs("invalid RPC port\n", stderr)
            exit(2)
        }

        do {
            try run(url: url, downloadDirectory: downloadDirectory, rpcPort: rpcPort)
            print("app download smoke test passed")
            exit(0)
        } catch {
            fputs("app download smoke test failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run(url: String, downloadDirectory: String, rpcPort: Int) throws {
        let secret = "ariaflow-app-smoke"
        var settings = AppSettings()
        settings.autoConnectEngine = false
        settings.downloadDirectory = downloadDirectory
        settings.rpcPort = rpcPort
        let smokeBlocklistPath = ProcessInfo.processInfo.environment["ARIAFLOW_SMOKE_BLOCKLIST_PATH"] ?? ""
        if !smokeBlocklistPath.isEmpty {
            let contents = try String(contentsOfFile: smokeBlocklistPath, encoding: .utf8)
            _ = try PeerBlocklistFile.installValidatedCache(contents: contents)
            settings.btPeerBlocklistURL = "https://ariaflow.smoke/blocklist.txt"
        }

        let engineManager = EngineManager()
        try engineManager.startIfNeeded(settings: settings, rpcSecret: secret)
        defer { engineManager.stop() }

        let client = Aria2Client(port: rpcPort, token: secret)
        try waitForEngine(client: client)
        if let expectedBlocklistPath = try PeerBlocklistFile.resolvedLocalPath(forURLString: settings.btPeerBlocklistURL) {
            let actualBlocklistPath = try client.getGlobalOptionSync()["bt-peer-blocklist"]
            guard actualBlocklistPath == expectedBlocklistPath else {
                throw SmokeDownloadError.blocklistNotLoaded
            }
        }
        let gid = try client.addUriSync([url], options: ["dir": downloadDirectory])
        try waitForDownload(gid: gid, client: client)
    }

    private static func waitForEngine(client: Aria2Client) throws {
        var lastError: Error?
        for _ in 0..<40 {
            do {
                _ = try client.getVersionSync()
                return
            } catch {
                lastError = error
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
        throw lastError ?? SmokeDownloadError.timeout
    }

    private static func waitForDownload(gid: String, client: Aria2Client) throws {
        for _ in 0..<100 {
            let task = try client.tellStatusSync(gid: gid)
            switch task.status {
            case "complete":
                return
            case "error", "removed":
                throw SmokeDownloadError.downloadFailed(task.errorMessage ?? task.status)
            default:
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
        throw SmokeDownloadError.timeout
    }
}

private enum SmokeDownloadError: LocalizedError {
    case timeout
    case downloadFailed(String)
    case blocklistNotLoaded

    var errorDescription: String? {
        switch self {
        case .timeout:
            "timed out waiting for aria2"
        case .downloadFailed(let message):
            "download failed: \(message)"
        case .blocklistNotLoaded:
            "bundled peer blocklist was not loaded"
        }
    }
}
