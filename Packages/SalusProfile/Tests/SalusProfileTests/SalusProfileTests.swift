import Testing

@testable import SalusProfile

@Suite("SalusProfile module")
struct SalusProfileModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(SalusProfileModule.name == "SalusProfile")
    }
}
