import Testing

@testable import SalusDatabase

@Suite("SalusDatabase module")
struct SalusDatabaseModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(SalusDatabaseModule.name == "SalusDatabase")
    }
}
