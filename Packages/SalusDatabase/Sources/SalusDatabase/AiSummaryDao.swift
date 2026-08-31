// Ported 1:1 from `core/database/src/main/kotlin/com/alicansekban/salus/core/database/dao/AiSummaryDao.kt`.
//
// Conventions — the plain struct over the database, the `@Query` strings carried verbatim — are
// `ProfileDao`'s; its doc comments explain why each of them is what it is, and are not repeated
// here.
//
// One shape differs from the other DAOs on purpose, and it is the Android twin's doing: Room's
// `AiSummaryDao` is an interface, so the repository that consumes it (`AiSummaryRepositoryImpl`)
// depends on the abstraction and a test can hand it a fake. The other DAOs here are concrete
// structs because nothing outside `SalusDatabase` needs to substitute them; this one is a protocol
// for exactly the reason Room's is — the gating core's tests drive the cache with an in-memory
// double. `GRDBAiSummaryDao` is the production implementation.
//
// The two methods never throw, and that too is the Android twin's doing: Room's `AiSummaryDao` is
// a `suspend fun` interface that never declares a checked exception, and the repository answers
// every request with a `SummaryOutcome`, which has no case for a database failure. To keep that
// contract, `GRDBAiSummaryDao` swallows its GRDB errors (`try?`) rather than throwing: a failed
// cache read answers "no cache" and a failed write is a no-op, so the gating core never has to
// invent a failure case the Android twin does not have.

import GRDB

/// Reads and writes the per-period, per-language summary cache (`AiSummaryRecord`).
public protocol AiSummaryDao: Sendable {
    /// The cached summary for one period + language key, or none (`AiSummaryDao.kt:12-16`).
    func get(periodType: String, startEpochDay: Int, language: String) async -> AiSummaryRecord?

    /// Replaces the cached summary for the period + language key (`AiSummaryDao.kt:18-24`).
    func upsert(_ record: AiSummaryRecord) async
}

/// The GRDB-backed `AiSummaryDao`.
public struct GRDBAiSummaryDao: AiSummaryDao {
    private let database: SalusDatabase

    public init(database: SalusDatabase) {
        self.database = database
    }

    public func get(periodType: String, startEpochDay: Int, language: String) async -> AiSummaryRecord? {
        // The query is the Kotlin `@Query` string verbatim — `LIMIT 1` included, even though the
        // primary key already makes the row unique, because the source says so.
        try? await database.reader.read { db in
            try AiSummaryRecord.fetchOne(
                db,
                sql: """
                SELECT * FROM ai_summaries
                WHERE period_type = ? AND start_epoch_day = ? AND language = ?
                LIMIT 1
                """,
                arguments: [periodType, startEpochDay, language]
            )
        }
    }

    public func upsert(_ record: AiSummaryRecord) async {
        // GRDB's `upsert` is SQLite's `ON CONFLICT DO UPDATE`, which — unlike `INSERT OR REPLACE` —
        // updates in place rather than deleting and re-inserting, so a regenerated summary
        // supersedes the old one wholesale without touching the row's identity.
        try? await database.writer.write { db in
            try record.upsert(db)
        }
    }
}
