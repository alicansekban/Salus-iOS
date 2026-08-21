import Testing

@testable import SalusAI

@Suite("SalusAI module")
struct SalusAIModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(SalusAIModule.name == "SalusAI")
    }
}
