// Ported 1:1 from `core/database/src/main/kotlin/com/alicansekban/salus/core/database/dao/ProfileDao.kt`.
//
// Room's `@Dao` is an interface it generates an implementation for; GRDB has no such step, so the
// DAO is a plain struct over the database and each method carries the SQL the annotation held.
// The queries are the Kotlin `@Query` strings verbatim — `WHERE is_default = 1 LIMIT 1` and the
// rest — because they are the semantics, not an implementation detail: "the default profile" is
// defined as the first row with `is_default = 1`, not as `defaultProfileId`.
//
// This is the only DAO in iOS-M1. The other six ship with the features that read them; the
// records are here already so every feature finds its table proven.

import GRDB

/// Reads and writes the profile row.
public struct ProfileDao: Sendable {
    private let database: SalusDatabase

    public init(database: SalusDatabase) {
        self.database = database
    }

    /// The twin of Room's `@Upsert` (`ProfileDao.kt:13-14`): insert, or replace the row that
    /// shares the primary key. GRDB's `upsert` is SQLite's `ON CONFLICT DO UPDATE`, which — unlike
    /// `INSERT OR REPLACE` — updates in place rather than deleting and re-inserting, so the
    /// cascades hanging off `profiles` do not fire on a plain edit.
    public func upsert(_ profile: ProfileRecord) async throws {
        try await database.writer.write { db in
            try profile.upsert(db)
        }
    }

    /// One-shot read of the default profile (`ProfileDao.kt:19-20`).
    public func getDefaultProfile() async throws -> ProfileRecord? {
        try await database.reader.read { db in
            try ProfileRecord.fetchOne(db, sql: Self.defaultProfileSql)
        }
    }

    /// `ProfileDao.kt:22-23`.
    public func getById(_ id: String) async throws -> ProfileRecord? {
        try await database.reader.read { db in
            try ProfileRecord.fetchOne(db, sql: "SELECT * FROM profiles WHERE id = ?", arguments: [id])
        }
    }

    /// `ProfileDao.kt:25-26`.
    public func count() async throws -> Int {
        try await database.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM profiles") ?? 0
        }
    }

    /// The twin of Kotlin's `Flow<ProfileEntity?>` (`ProfileDao.kt:16-17`): the current value,
    /// then a fresh one after every transaction that changes the `profiles` table.
    ///
    /// `AsyncStream` rather than the throwing `AsyncValueObservation` it is built on, because the
    /// Kotlin `Flow` this ports does not carry an error channel either. A failed observation ends
    /// the stream instead of crashing the screen that reads it; there is no error a UI could act
    /// on here beyond showing nothing, which is what an ended stream already shows.
    public func observeDefaultProfile() -> AsyncStream<ProfileRecord?> {
        let observation = ValueObservation.tracking { db in
            try ProfileRecord.fetchOne(db, sql: Self.defaultProfileSql)
        }
        let values = observation.values(in: database.reader)

        return AsyncStream { continuation in
            let task = Task {
                do {
                    for try await profile in values {
                        continuation.yield(profile)
                    }
                } catch {
                    // Fall through to `finish()`: see the note above.
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// `ProfileDao.kt:16` and `:19`, which are deliberately the same string on Android too.
    private static let defaultProfileSql = "SELECT * FROM profiles WHERE is_default = 1 LIMIT 1"
}
