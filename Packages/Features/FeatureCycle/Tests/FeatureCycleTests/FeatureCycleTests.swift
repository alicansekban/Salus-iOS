import Testing

@testable import FeatureCycle

@Suite("FeatureCycle module")
struct FeatureCycleModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(FeatureCycleModule.name == "FeatureCycle")
    }
}
