import Foundation
import Testing
@testable import AriaFlow

@Suite("Task mapping")
@MainActor
struct TaskMappingTests {
    @Test("infers protocol labels from source URLs and BT metadata")
    func protocolLabels() {
        #expect(AppStore.protocolLabel(hasBitTorrent: true, sourceURLs: ["https://example.com/a"]) == "BT")
        #expect(AppStore.protocolLabel(hasBitTorrent: false, sourceURLs: ["https://cdn.example/file.bin"]) == "HTTP")
        #expect(AppStore.protocolLabel(hasBitTorrent: false, sourceURLs: ["magnet:?xt=urn:btih:abc"]) == "Magnet")
        #expect(AppStore.protocolLabel(hasBitTorrent: false, sourceURLs: ["ed2k://|file|x|1|hash|/"]) == "ED2K")
        #expect(AppStore.protocolLabel(hasBitTorrent: false, sourceURLs: ["ftp://host/a"]) == "FTP")
        #expect(AppStore.protocolLabel(hasBitTorrent: false, sourceURLs: []) == "URL")
    }

    @Test("prefers error message for task detail")
    func taskDetail() {
        #expect(
            AppStore.taskDetail(
                errorMessage: "disk full",
                sourceURLs: ["https://example.com/a"],
                status: .failed
            ) == "disk full"
        )
        #expect(
            AppStore.taskDetail(
                errorMessage: nil,
                sourceURLs: ["https://example.com/a"],
                status: .active
            ) == "https://example.com/a"
        )
        #expect(
            AppStore.taskDetail(
                errorMessage: nil,
                sourceURLs: [],
                status: .complete
            ).isEmpty == false
        )
    }

    @Test("maps aria2 statuses")
    func statuses() {
        #expect(AppStore.makeTaskStatus(from: "active") == .active)
        #expect(AppStore.makeTaskStatus(from: "paused") == .paused)
        #expect(AppStore.makeTaskStatus(from: "complete") == .complete)
        #expect(AppStore.makeTaskStatus(from: "error") == .failed)
    }
}
