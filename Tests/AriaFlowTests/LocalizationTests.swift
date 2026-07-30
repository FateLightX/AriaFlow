import Testing
@testable import AriaFlow

@Suite("Localization")
struct LocalizationTests {
    @Test("uses Chinese for every Chinese locale")
    func chineseLocales() {
        #expect(L10n.language(for: ["zh-Hans-CN"]) == .chinese)
        #expect(L10n.language(for: ["zh-Hant-TW"]) == .chinese)
        #expect(L10n.language(for: ["zh-HK"]) == .chinese)
    }

    @Test("uses English for every non-Chinese locale")
    func nonChineseLocales() {
        #expect(L10n.language(for: ["en-US"]) == .english)
        #expect(L10n.language(for: ["ja-JP"]) == .english)
        #expect(L10n.language(for: ["fr-FR"]) == .english)
        #expect(L10n.language(for: []) == .english)
    }

    @Test("localizes static and interpolated text")
    func translations() {
        #expect(L10n.tr("设置", preferredLanguages: ["zh-Hans"]) == "设置")
        #expect(L10n.tr("设置", preferredLanguages: ["en-US"]) == "Settings")
        #expect(L10n.tr("aria2 \("1.0") 已连接", preferredLanguages: ["de-DE"]) == "aria2 1.0 connected")
    }
}
