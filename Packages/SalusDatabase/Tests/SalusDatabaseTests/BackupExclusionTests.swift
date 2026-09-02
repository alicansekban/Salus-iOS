// Parity-ledger row S-10. Android's `allowBackup=false` is a manifest line a reviewer can read;
// iOS' equivalent is a resource value on a file, which nothing surfaces. These tests are what
// makes it visible: they assert the flag is actually readable back off the file, so a refactor
// that drops the call — or reintroduces the `let`-URL mistake that makes `setResourceValues`
// silently no-op — fails here rather than in a stranger's iCloud backup.

import Foundation
import SalusTesting
import Testing

@testable import SalusDatabase

@Suite("SalusDatabase backup exclusion")
struct BackupExclusionTests {
    private let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_700_000_000))

    /// A temporary directory, removed when the caller's scope ends.
    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("salus-backup-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func isExcludedFromBackup(_ url: URL) throws -> Bool {
        try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup ?? false
    }

    @Test("a real database file reads back as excluded from backup")
    func aRealDatabaseFileReadsBackAsExcluded() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent(SalusDatabase.name)

        // Opening is what creates the file; the flag cannot be set on a path that does not exist.
        _ = try SalusDatabase(path: file.path, clock: clock)
        #expect(try isExcludedFromBackup(file) == false, "the default is backed up — that is the bug S-10 is about")

        try SalusDatabase.excludeFromBackup(at: file)

        #expect(try isExcludedFromBackup(file) == true)
    }

    @Test("a journal sidecar next to the database is excluded too")
    func aJournalSidecarIsExcludedToo() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent(SalusDatabase.name)
        let journal = URL(fileURLWithPath: file.path + "-journal")
        try Data().write(to: file)
        try Data().write(to: journal)

        try SalusDatabase.excludeFromBackup(at: file)

        #expect(try isExcludedFromBackup(journal) == true)
    }

    @Test("a missing sidecar is not an error")
    func aMissingSidecarIsNotAnError() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent(SalusDatabase.name)
        try Data().write(to: file)

        // No `-journal`, `-wal` or `-shm` exists: the common case, since `DatabaseQueue` leaves
        // journal mode at `delete` and the rollback journal only lives for the length of a write.
        try SalusDatabase.excludeFromBackup(at: file)

        #expect(try isExcludedFromBackup(file) == true)
    }

    @Test("a path with no file throws rather than silently doing nothing")
    func aPathWithNoFileThrows() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let missing = directory.appendingPathComponent(SalusDatabase.name)

        #expect(throws: (any Error).self) {
            try SalusDatabase.excludeFromBackup(at: missing)
        }
    }
}
