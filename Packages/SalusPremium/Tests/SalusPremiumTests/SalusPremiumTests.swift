import Testing

@testable import SalusPremium

@Suite("SalusPremium module")
struct SalusPremiumModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(SalusPremiumModule.name == "SalusPremium")
    }
}
