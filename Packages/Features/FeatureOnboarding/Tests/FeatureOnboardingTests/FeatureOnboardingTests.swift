import Testing

@testable import FeatureOnboarding

@Suite("FeatureOnboarding module")
struct FeatureOnboardingModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(FeatureOnboardingModule.name == "FeatureOnboarding")
    }
}
