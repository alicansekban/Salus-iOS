import Testing

@testable import SalusBackup

@Suite("SalusBackup module")
struct SalusBackupModuleTests {
    @Test("module identifier is stable")
    func moduleIdentifierIsStable() {
        #expect(SalusBackupModule.name == "SalusBackup")
    }
}
