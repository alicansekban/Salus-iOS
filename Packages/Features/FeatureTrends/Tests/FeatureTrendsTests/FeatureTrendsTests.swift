import Testing

@testable import FeatureTrends

@Suite("FeatureTrends module")
struct FeatureTrendsModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(FeatureTrendsModule.name == "FeatureTrends")
    }
}
