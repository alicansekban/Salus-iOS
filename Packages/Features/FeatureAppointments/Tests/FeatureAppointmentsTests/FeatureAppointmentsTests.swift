import Testing

@testable import FeatureAppointments

@Suite("FeatureAppointments module")
struct FeatureAppointmentsModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(FeatureAppointmentsModule.name == "FeatureAppointments")
    }
}
