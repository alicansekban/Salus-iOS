import Testing

@testable import SalusModel

@Suite("SalusModel module")
struct SalusModelModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(SalusModelModule.name == "SalusModel")
    }
}
