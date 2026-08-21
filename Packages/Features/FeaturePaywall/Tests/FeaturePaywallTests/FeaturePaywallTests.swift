import Testing

@testable import FeaturePaywall

@Suite("FeaturePaywall module")
struct FeaturePaywallModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(FeaturePaywallModule.name == "FeaturePaywall")
    }
}
