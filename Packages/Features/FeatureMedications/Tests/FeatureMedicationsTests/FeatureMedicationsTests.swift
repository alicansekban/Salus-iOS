import Testing

@testable import FeatureMedications

@Suite("FeatureMedications module")
struct FeatureMedicationsModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(FeatureMedicationsModule.name == "FeatureMedications")
    }
}
