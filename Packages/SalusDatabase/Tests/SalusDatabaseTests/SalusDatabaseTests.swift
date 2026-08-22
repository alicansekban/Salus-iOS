// The constants and the two ways in. `MigrationTests` and `ProfileDaoTests` both build on
// `inMemory`; the file-backed initializer is what the app actually calls, so it gets its own
// check that opening, migrating and re-opening a real file works.

import Foundation
import GRDB
import SalusTesting
import Testing

@testable import SalusDatabase

@Suite("SalusDatabase")
struct SalusDatabaseTests {
    private let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_700_000_000))

    /// `SalusDatabase.kt:60` and `:64`. Both strings are persisted contract — the file name is
    /// what a backup restore looks for, the profile id is what every `profile_id` column holds.
    @Test("the persisted names match Android")
    func persistedNamesMatchAndroid() {
        #expect(SalusDatabase.name == "salus.db")
        #expect(SalusDatabase.defaultProfileId == "default-profile")
    }

    @Test("opening a file path creates, migrates and re-opens it")
    func openingAFilePathCreatesMigratesAndReopensIt() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("salus-db-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let path = directory.appendingPathComponent(SalusDatabase.name).path

        let database = try SalusDatabase(path: path, clock: clock)
        let updated = try await database.writer.write { db in
            try ProfileRecord.updateAll(db, [Column("display_name").set(to: "Ada")])
        }
        #expect(updated == 1)
        #expect(FileManager.default.fileExists(atPath: path))

        // A second open must migrate nothing and keep what the first one wrote.
        let reopened = try SalusDatabase(path: path, clock: clock)
        let profile = try await reopened.reader.read { db in
            try ProfileRecord.fetchOne(db, key: SalusDatabase.defaultProfileId)
        }
        #expect(profile?.displayName == "Ada")
        #expect(try await reopened.reader.read { db in try ProfileRecord.fetchCount(db) } == 1)
    }
}
