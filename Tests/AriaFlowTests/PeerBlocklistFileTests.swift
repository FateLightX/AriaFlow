import Foundation
import Testing
@testable import AriaFlow

@Suite("Peer Blocklist")
struct PeerBlocklistFileTests {
    @Test("validates IPv4, IPv6, CIDR, comments, and blank lines")
    func validatesSupportedRules() throws {
        let contents = """
        # BTN-compatible rules
        203.0.113.25
        198.51.100.0/24
        2001:db8::1234
        2001:db8:abcd::/48

        """
        let cacheURL = try temporaryCache(contents: contents)
        defer { try? FileManager.default.removeItem(at: cacheURL.deletingLastPathComponent()) }

        #expect(try PeerBlocklistFile.validatedCachePath(cacheURL) == cacheURL.standardizedFileURL.path)
        #expect(
            try PeerBlocklistFile.resolvedLocalPath(
                forURLString: "https://example.com/blocklist.txt",
                cacheURL: cacheURL
            ) == cacheURL.standardizedFileURL.path
        )
    }

    @Test("rejects invalid rules with their line number")
    func rejectsInvalidRule() throws {
        do {
            try PeerBlocklistFile.validateContents("203.0.113.0/24\nnot-an-ip\n")
            Issue.record("Expected invalid rule error")
        } catch let error as PeerBlocklistFileError {
            #expect(error.errorDescription?.contains("第 2 行") == true)
        }
    }

    @Test("settings keep only http(s) URLs and ignore legacy paths")
    func decodesSettings() throws {
        #expect(AppSettings().btPeerBlocklistURL.isEmpty)
        let empty = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        #expect(empty.btPeerBlocklistURL.isEmpty)

        let legacyPath = #"{"btPeerBlocklistPath":"/tmp/blocklist.txt"}"#
        let dropped = try JSONDecoder().decode(AppSettings.self, from: Data(legacyPath.utf8))
        #expect(dropped.btPeerBlocklistURL.isEmpty)

        let remote = #"{"btPeerBlocklistURL":" https://example.com/list.txt "}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(remote.utf8))
        #expect(settings.btPeerBlocklistURL == "https://example.com/list.txt")

        let fileURL = #"{"btPeerBlocklistURL":"file:///tmp/blocklist.txt"}"#
        let ignored = try JSONDecoder().decode(AppSettings.self, from: Data(fileURL.utf8))
        #expect(ignored.btPeerBlocklistURL.isEmpty)
    }

    @Test("normalizes http links and rejects paths or other schemes")
    func normalizesLinks() throws {
        #expect(try PeerBlocklistFile.normalizedURLString(" https://example.com/list.txt ") == "https://example.com/list.txt")
        do {
            _ = try PeerBlocklistFile.normalizedURLString("ftp://example.com/list.txt")
            Issue.record("Expected unsupported scheme")
        } catch let error as PeerBlocklistFileError {
            #expect(error.errorDescription?.contains("ftp") == true)
        }

        do {
            _ = try PeerBlocklistFile.normalizedURLString("/tmp/blocklist.txt")
            Issue.record("Expected invalid URL for local path")
        } catch let error as PeerBlocklistFileError {
            #expect(error.errorDescription?.contains("无效") == true)
        }

        do {
            _ = try PeerBlocklistFile.normalizedURLString("file:///tmp/blocklist.txt")
            Issue.record("Expected unsupported file scheme")
        } catch let error as PeerBlocklistFileError {
            #expect(error.errorDescription?.contains("file") == true)
        }
    }

    @Test("rejects missing cache files")
    func rejectsMissingCache() {
        let cacheURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "missing-blocklist.txt")

        do {
            _ = try PeerBlocklistFile.validatedCachePath(cacheURL)
            Issue.record("Expected unavailable cache error")
        } catch let error as PeerBlocklistFileError {
            #expect(error.errorDescription?.contains("不可读") == true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("installs validated cache contents")
    func installsCache() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let cacheURL = directory.appending(path: "bt-peer-blocklist.txt")
        let path = try PeerBlocklistFile.installValidatedCache(
            contents: "203.0.113.1\n",
            cacheURL: cacheURL
        )
        #expect(path == cacheURL.standardizedFileURL.path)
        #expect(try String(contentsOf: cacheURL, encoding: .utf8) == "203.0.113.1\n")
    }

    private func temporaryCache(contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "blocklist.txt")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
