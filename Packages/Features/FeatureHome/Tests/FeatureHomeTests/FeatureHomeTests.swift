import Testing

@testable import FeatureHome

@Suite("FeatureHome module")
struct FeatureHomeModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(FeatureHomeModule.name == "FeatureHome")
    }
}
