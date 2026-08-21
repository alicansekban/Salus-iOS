import Testing

@testable import SalusReminder

@Suite("SalusReminder module")
struct SalusReminderModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(SalusReminderModule.name == "SalusReminder")
    }
}
