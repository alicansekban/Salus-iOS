import Testing

@testable import SalusUI

@Suite("SalusUI module")
struct SalusUIModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(SalusUIModule.name == "SalusUI")
    }
}
