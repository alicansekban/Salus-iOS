import Testing

@testable import FeatureVitals

@Suite("FeatureVitals module")
struct FeatureVitalsModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(FeatureVitalsModule.name == "FeatureVitals")
    }
}
