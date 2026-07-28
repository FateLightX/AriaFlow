import Testing
@testable import AriaFlow

@Suite("Software updater")
struct SoftwareUpdaterTests {
    @Test("compares semantic release versions")
    func comparesVersions() {
        #expect(SoftwareUpdater.isVersion("0.3.4", newerThan: "0.3.3"))
        #expect(SoftwareUpdater.isVersion("v1.0.0", newerThan: "0.9.9"))
        #expect(!SoftwareUpdater.isVersion("0.3.3", newerThan: "0.3.3"))
        #expect(!SoftwareUpdater.isVersion("0.3.2", newerThan: "0.3.3"))
    }
}
