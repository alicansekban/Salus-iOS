import Testing

@testable import FeatureSettings

@Suite("FeatureSettings module")
struct FeatureSettingsModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(FeatureSettingsModule.name == "FeatureSettings")
    }
}
