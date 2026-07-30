import Testing
@testable import AriaFlow

@Suite("Software updater")
struct SoftwareUpdaterTests {
    @Test("compares semantic release versions")
    func comparesVersions() {
        #expect(SoftwareUpdater.isVersion("1.2.0", newerThan: "1.1.9"))
        #expect(SoftwareUpdater.isVersion("v2.0.0", newerThan: "1.9.9"))
        #expect(!SoftwareUpdater.isVersion("1.2.0", newerThan: "1.2.0"))
        #expect(!SoftwareUpdater.isVersion("1.1.9", newerThan: "1.2.0"))
    }
}
