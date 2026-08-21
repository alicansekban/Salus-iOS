import Testing

@testable import SalusNotifications

@Suite("SalusNotifications module")
struct SalusNotificationsModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(SalusNotificationsModule.name == "SalusNotifications")
    }
}
