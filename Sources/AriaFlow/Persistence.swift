import Foundation

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

    static var peerBlocklistCacheURL: URL {
        directory.appending(path: "bt-peer-blocklist.txt")
    }

    static var engineRuntimeConfigURL: URL {
        directory.appending(path: "engine-runtime.conf")
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
