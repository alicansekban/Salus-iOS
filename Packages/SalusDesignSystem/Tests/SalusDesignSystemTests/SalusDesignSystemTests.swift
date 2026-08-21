import Testing

@testable import SalusDesignSystem

@Suite("SalusDesignSystem module")
struct SalusDesignSystemModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(SalusDesignSystemModule.name == "SalusDesignSystem")
    }
}
