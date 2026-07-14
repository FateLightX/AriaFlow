import Foundation
import Testing
@testable import AriaFlow

@Suite("Peer Blocklist")
struct PeerBlocklistFileTests {
    @Test("validates IPv4, IPv6, CIDR, comments, and blank lines")
    func validatesSupportedRules() throws {
        let url = try temporaryFile(
            contents: """
            # BTN-compatible rules
            203.0.113.25
            198.51.100.0/24
            2001:db8::1234
            2001:db8:abcd::/48

            """
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        #expect(try PeerBlocklistFile.validatedPath(url.path) == url.standardizedFileURL.path)
    }

    @Test("rejects invalid rules with their line number")
    func rejectsInvalidRule() throws {
        let url = try temporaryFile(contents: "203.0.113.0/24\nnot-an-ip\n")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        do {
            _ = try PeerBlocklistFile.validatedPath(url.path)
            Issue.record("Expected invalid rule error")
        } catch let error as PeerBlocklistFileError {
            #expect(error.errorDescription?.contains("第 2 行") == true)
        }
    }

    @Test("legacy settings default to no blocklist")
    func decodesLegacySettings() throws {
        #expect(AppSettings().btPeerBlocklistPath.isEmpty)
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        #expect(settings.btPeerBlocklistPath.isEmpty)
    }

    @Test("rejects missing files")
    func rejectsMissingFile() {
        let path = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .path

        do {
            _ = try PeerBlocklistFile.validatedPath(path)
            Issue.record("Expected unavailable file error")
        } catch let error as PeerBlocklistFileError {
            #expect(error.errorDescription?.contains("不存在或不可读") == true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func temporaryFile(contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "blocklist.txt")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
