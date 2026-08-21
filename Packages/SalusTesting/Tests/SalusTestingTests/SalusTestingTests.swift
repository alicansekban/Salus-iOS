import Testing

@testable import SalusTesting

@Suite("SalusTesting module")
struct SalusTestingModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(SalusTestingModule.name == "SalusTesting")
    }
}
