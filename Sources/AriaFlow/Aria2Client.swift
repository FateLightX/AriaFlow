import Foundation

struct Aria2Version: Decodable {
    var version: String
    var enabledFeatures: [String]
}

struct Aria2GlobalStat: Decodable {
    var downloadSpeed: String
    var uploadSpeed: String
    var numActive: String
    var numWaiting: String
    var numStopped: String
    var numStoppedTotal: String?
}

struct Aria2Task: Decodable, Identifiable {
    var gid: String
    var status: String
    var totalLength: String?
    var completedLength: String?
    var uploadLength: String?
    var downloadSpeed: String?
    var uploadSpeed: String?
    var dir: String?
    var errorCode: String?
    var errorMessage: String?
    var files: [Aria2File]?
    var bittorrent: Aria2BitTorrent?

    var id: String { gid }
}

struct Aria2BitTorrent: Decodable {
    var info: Aria2BitTorrentInfo?
    var infoHash: String?
}

struct Aria2BitTorrentInfo: Decodable {
    var name: String?
}

struct Aria2File: Decodable, Identifiable {
    var index: String
    var path: String
    var length: String
    var completedLength: String
    var selected: String
    var uris: [Aria2URI]?

    var id: String { index }
}

struct Aria2URI: Decodable {
    var uri: String
    var status: String?
}

struct Aria2RPCError: Error, Decodable, LocalizedError {
    var code: Int
    var message: String

    var errorDescription: String? {
        message
    }
}

enum Aria2ClientError: Error, LocalizedError {
    case invalidHTTPStatus(Int)
    case missingResult

    var errorDescription: String? {
        switch self {
        case .invalidHTTPStatus(let statusCode): "aria2 RPC HTTP 状态异常：\(statusCode)"
        case .missingResult: "aria2 RPC 没有返回结果"
        }
    }
}

struct Aria2Client {
    var endpoint: URL
    var token: String?

    init(host: String = "127.0.0.1", port: Int, token: String? = nil) {
        endpoint = URL(string: "http://\(host):\(port)/jsonrpc")!
        self.token = token
    }

    func getVersion() async throws -> Aria2Version {
        try await call("aria2.getVersion")
    }

    func isReachable() async -> Bool {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 1
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return response is HTTPURLResponse
        } catch {
            return false
        }
    }

    func getGlobalStat() async throws -> Aria2GlobalStat {
        try await call("aria2.getGlobalStat")
    }

    func tellActive() async throws -> [Aria2Task] {
        try await call("aria2.tellActive")
    }

    func tellWaiting(offset: Int = 0, count: Int = 100) async throws -> [Aria2Task] {
        try await call("aria2.tellWaiting", params: [offset, count])
    }

    func tellStopped(offset: Int = 0, count: Int = 100) async throws -> [Aria2Task] {
        try await call("aria2.tellStopped", params: [offset, count])
    }

    func tellStatus(gid: String) async throws -> Aria2Task {
        try await call("aria2.tellStatus", params: [gid])
    }

    func addUri(_ uris: [String], options: [String: String] = [:]) async throws -> String {
        try await call("aria2.addUri", params: [uris, options])
    }

    func addTorrent(_ base64Torrent: String, options: [String: String] = [:]) async throws -> String {
        try await call("aria2.addTorrent", params: [base64Torrent, [], options])
    }

    func pause(gid: String) async throws -> String {
        try await call("aria2.pause", params: [gid])
    }

    func forcePause(gid: String) async throws -> String {
        try await call("aria2.forcePause", params: [gid])
    }

    func pauseAll() async throws -> String {
        try await call("aria2.pauseAll")
    }

    func unpause(gid: String) async throws -> String {
        try await call("aria2.unpause", params: [gid])
    }

    func unpauseAll() async throws -> String {
        try await call("aria2.unpauseAll")
    }

    func remove(gid: String) async throws -> String {
        try await call("aria2.remove", params: [gid])
    }

    func forceRemove(gid: String) async throws -> String {
        try await call("aria2.forceRemove", params: [gid])
    }

    func removeDownloadResult(gid: String) async throws -> String {
        try await call("aria2.removeDownloadResult", params: [gid])
    }

    func getFiles(gid: String) async throws -> [Aria2File] {
        try await call("aria2.getFiles", params: [gid])
    }

    func changeOption(gid: String, options: [String: String]) async throws -> String {
        try await call("aria2.changeOption", params: [gid, options])
    }

    func changeGlobalOption(_ options: [String: String]) async throws -> String {
        try await call("aria2.changeGlobalOption", params: [options])
    }

    func saveSession() async throws -> String {
        try await call("aria2.saveSession")
    }

    func forceShutdown() async throws -> String {
        try await call("aria2.forceShutdown")
    }

    func getVersionSync() throws -> Aria2Version {
        try callSync("aria2.getVersion")
    }

    func getGlobalOptionSync() throws -> [String: String] {
        try callSync("aria2.getGlobalOption")
    }

    func addUriSync(_ uris: [String], options: [String: String] = [:]) throws -> String {
        try callSync("aria2.addUri", params: [uris, options])
    }

    func tellStatusSync(gid: String) throws -> Aria2Task {
        try callSync("aria2.tellStatus", params: [gid])
    }

    private func call<Result: Decodable>(_ method: String, params: [Any] = []) async throws -> Result {
        var requestParams: [Any] = []
        if let token, !token.isEmpty {
            requestParams.append("token:\(token)")
        }
        requestParams.append(contentsOf: params)

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": UUID().uuidString,
            "method": method,
            "params": requestParams
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 3
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw Aria2ClientError.invalidHTTPStatus(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(RPCResponse<Result>.self, from: data)
        if let error = decoded.error {
            throw error
        }

        guard let result = decoded.result else {
            throw Aria2ClientError.missingResult
        }
        return result
    }

    private func callSync<Result: Decodable>(_ method: String, params: [Any] = []) throws -> Result {
        var requestParams: [Any] = []
        if let token, !token.isEmpty {
            requestParams.append("token:\(token)")
        }
        requestParams.append(contentsOf: params)

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": UUID().uuidString,
            "method": method,
            "params": requestParams
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 3
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let semaphore = DispatchSemaphore(value: 0)
        let resultBox = SyncRPCResultBox()

        URLSession.shared.dataTask(with: request) { data, response, error in
            resultBox.store(data: data, response: response, error: error)
            semaphore.signal()
        }.resume()

        semaphore.wait()

        let (dataResult, responseResult, errorResult) = resultBox.load()

        if let errorResult {
            throw errorResult
        }

        if let httpResponse = responseResult as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw Aria2ClientError.invalidHTTPStatus(httpResponse.statusCode)
        }

        guard let dataResult else {
            throw Aria2ClientError.missingResult
        }

        let decoded = try JSONDecoder().decode(RPCResponse<Result>.self, from: dataResult)
        if let error = decoded.error {
            throw error
        }

        guard let result = decoded.result else {
            throw Aria2ClientError.missingResult
        }
        return result
    }
}

private final class SyncRPCResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    private var response: URLResponse?
    private var error: Error?

    func store(data: Data?, response: URLResponse?, error: Error?) {
        lock.lock()
        self.data = data
        self.response = response
        self.error = error
        lock.unlock()
    }

    func load() -> (Data?, URLResponse?, Error?) {
        lock.lock()
        defer { lock.unlock() }
        return (data, response, error)
    }
}

private struct RPCResponse<Result: Decodable>: Decodable {
    var result: Result?
    var error: Aria2RPCError?
}
