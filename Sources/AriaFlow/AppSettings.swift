import Foundation

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
    var btPeerBlocklistURL = ""
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
        case btPeerBlocklistURL
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
        let decodedURL = try container.decodeIfPresent(String.self, forKey: .btPeerBlocklistURL) ?? ""
        btPeerBlocklistURL = (try? PeerBlocklistFile.normalizedURLString(decodedURL)) ?? ""
        rpcPort = try container.decodeIfPresent(Int.self, forKey: .rpcPort) ?? 6800
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(autoConnectEngine, forKey: .autoConnectEngine)
        try container.encode(downloadDirectory, forKey: .downloadDirectory)
        try container.encode(maxConcurrentDownloads, forKey: .maxConcurrentDownloads)
        try container.encode(splitCount, forKey: .splitCount)
        try container.encode(maxConnectionsPerServer, forKey: .maxConnectionsPerServer)
        try container.encode(downloadSpeedLimit, forKey: .downloadSpeedLimit)
        try container.encode(uploadSpeedLimit, forKey: .uploadSpeedLimit)
        try container.encode(showSpeedInMenuBar, forKey: .showSpeedInMenuBar)
        try container.encode(showMainWindowOnLaunch, forKey: .showMainWindowOnLaunch)
        try container.encode(keepRunningAfterMainWindowClose, forKey: .keepRunningAfterMainWindowClose)
        try container.encode(hideDockIconInMenuBarMode, forKey: .hideDockIconInMenuBarMode)
        try container.encode(btPeerBlocklistURL, forKey: .btPeerBlocklistURL)
        try container.encode(rpcPort, forKey: .rpcPort)
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
