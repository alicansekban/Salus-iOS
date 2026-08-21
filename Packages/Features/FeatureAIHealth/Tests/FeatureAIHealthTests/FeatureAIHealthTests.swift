import Testing

@testable import FeatureAIHealth

@Suite("FeatureAIHealth module")
struct FeatureAIHealthModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(FeatureAIHealthModule.name == "FeatureAIHealth")
    }
}
