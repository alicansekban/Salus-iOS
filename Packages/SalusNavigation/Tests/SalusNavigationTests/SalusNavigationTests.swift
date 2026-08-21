import Testing

@testable import SalusNavigation

@Suite("SalusNavigation module")
struct SalusNavigationModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(SalusNavigationModule.name == "SalusNavigation")
    }
}
