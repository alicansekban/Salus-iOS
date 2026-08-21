import Testing

@testable import SalusCommon

@Suite("SalusCommon module")
struct SalusCommonModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(SalusCommonModule.name == "SalusCommon")
    }
}
