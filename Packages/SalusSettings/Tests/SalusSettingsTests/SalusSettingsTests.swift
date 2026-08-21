import Testing

@testable import SalusSettings

@Suite("SalusSettings module")
struct SalusSettingsModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(SalusSettingsModule.name == "SalusSettings")
    }
}
