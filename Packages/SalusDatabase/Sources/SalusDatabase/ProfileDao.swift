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
    /// Throwing, because the `Flow` it ports throws. Room's `@Query`-backed flow re-runs the query
    /// on every invalidation and lets a failure propagate to the collector; a stream that quietly
    /// ended instead would hide a disk or corruption error behind an empty screen, which is a
    /// divergence rather than parity. A failed observation finishes the stream `throwing:` that
    /// error, so the caller decides what an unreadable database looks like.
    ///
    /// `.bufferingNewest(1)`, because Room conflates. `CoroutinesRoom.createFlow` pushes
    /// invalidations through a conflated channel, so a slow collector is handed the *current* row,
    /// never a queue of superseded ones. `AsyncThrowingStream` defaults to `.unbounded`, which
    /// would replay every intermediate value — the opposite behaviour, and stale by definition.
    public func observeDefaultProfile() -> AsyncThrowingStream<ProfileRecord?, any Error> {
        let observation = ValueObservation.tracking { db in
            try ProfileRecord.fetchOne(db, sql: Self.defaultProfileSql)
        }
        let values = observation.values(in: database.reader)

        return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                do {
                    for try await profile in values {
                        continuation.yield(profile)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // A consumer that stops reading — a screen that goes away, a cancelled task — must
            // stop the observation too, or it keeps re-querying for nobody.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// `ProfileDao.kt:16` and `:19`, which are deliberately the same string on Android too.
    private static let defaultProfileSql = "SELECT * FROM profiles WHERE is_default = 1 LIMIT 1"
}
