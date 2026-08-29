// Ported 1:1 from `core/database/src/main/kotlin/com/alicansekban/salus/core/database/dao/CycleDao.kt`.
//
// Conventions — the plain struct over the database, the `@Query` strings carried verbatim — are
// `ProfileDao`'s; its doc comments explain why each of them is what it is, and are not repeated
// here. The `AsyncThrowingStream` standing in for Room's `Flow` comes from `conflatedStream`,
// which is where that decision is written down.
//
// Four things are worth naming here.
//
// **Nothing in this file predicts anything.** Only recorded periods and recorded days are stored;
// the next-period estimate is computed from them at read time and never written back
// (`CycleEntity.kt:9`). A column for it would be a claim the database cannot take back.
//
// **`upsertPeriod` and `upsertDailyEntry` write with GRDB's `save`, not its `upsert`**, and that
// is a deliberate divergence (l) rather than a slip. Both tables carry a UNIQUE index that is not
// their primary key — `(profile_id, start_date)` and `(profile_id, date)` — and the two libraries
// part company exactly there. GRDB's `upsert` emits `ON CONFLICT DO UPDATE` with no conflict
// target, so a *new* id landing on a taken day silently overwrites the row that is already there.
// Room's `@Upsert` catches the constraint failure and retries as `UPDATE ... WHERE id = ?`
// (`EntityUpsertAdapter.kt:44-51`), which matches no row and silently writes nothing. Both hide a
// caller bug; neither is a behaviour to port. `save` is update-by-primary-key or insert, so the
// ordinary edit still updates its own row and the collision surfaces as the `DatabaseError` the
// unique index exists to raise. Every other table in this file has no unique index but its
// primary key, where `save` and `upsert` cannot differ, so they keep the package's `upsert`.
//
// `observeSymptoms` and `countSymptoms` carry **no** `profile_id`, and that is the schema, not an
// omission: the symptom catalog is global — seeded rows plus whatever the user added — and a
// daily entry reaches it through `cycle_entry_symptoms` (`CycleDao.kt:50-51`, `:72-73`).
//
// `saveDailyEntry` has no Kotlin twin: Android's repository issues `upsertDailyEntry` and
// `replaceEntrySymptoms` as two separate writes. Here they share one transaction (recorded
// divergence (a)), so a reader never sees a day beside the symptom set of its previous version.

import GRDB

/// Reads and writes recorded periods, the day-by-day cycle log, and the symptom catalog the log
/// points into.
public struct CycleDao: Sendable {
    private let database: SalusDatabase

    public init(database: SalusDatabase) {
        self.database = database
    }

    // MARK: - Periods

    /// `CycleDao.kt:16-17`.
    ///
    /// Update-by-id or insert (see the file header on `save` vs `upsert`): a period whose `id` is
    /// new but whose `(profile_id, start_date)` is already taken fails the unique index instead of
    /// merging into, or being swallowed by, the row that is there. The caller settles which one it
    /// means with `getPeriodByStart` first.
    public func upsertPeriod(_ period: CyclePeriodRecord) async throws {
        try await database.writer.write { db in
            try period.save(db)
        }
    }

    /// One profile's recorded periods, most recent start first (`CycleDao.kt:19-20`).
    public func observePeriods(profileId: String) -> AsyncThrowingStream<[CyclePeriodRecord], any Error> {
        let observation = ValueObservation.tracking { db in
            try CyclePeriodRecord.fetchAll(
                db,
                sql: "SELECT * FROM cycle_periods WHERE profile_id = ? ORDER BY start_date DESC",
                arguments: [profileId]
            )
        }
        return conflatedStream(observation.values(in: database.reader))
    }

    /// The period that starts on one day, if there is one (`CycleDao.kt:22-23`) — keyed by exactly
    /// the columns the unique index covers, which is what keeps `upsertPeriod` from having to throw
    /// in the ordinary case.
    public func getPeriodByStart(profileId: String, startEpochDay: Int) async throws -> CyclePeriodRecord? {
        try await database.reader.read { db in
            try CyclePeriodRecord.fetchOne(
                db,
                sql: "SELECT * FROM cycle_periods WHERE profile_id = ? AND start_date = ?",
                arguments: [profileId, startEpochDay]
            )
        }
    }

    /// `CycleDao.kt:25-26`.
    public func deletePeriodById(_ id: String) async throws {
        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM cycle_periods WHERE id = ?", arguments: [id])
        }
    }

    /// The period the user is currently in, if any (`CycleDao.kt:62-70`).
    ///
    /// "Open" is `end_date IS NULL` — a period is recorded when it starts and closed when it ends,
    /// so the newest unclosed one is the current one. `LIMIT 1` after `start_date DESC` is what
    /// makes an older row that was never closed lose to a newer one.
    public func getOpenPeriod(profileId: String) async throws -> CyclePeriodRecord? {
        try await database.reader.read { db in
            try CyclePeriodRecord.fetchOne(
                db,
                sql: """
                SELECT * FROM cycle_periods
                WHERE profile_id = ? AND end_date IS NULL
                ORDER BY start_date DESC
                LIMIT 1
                """,
                arguments: [profileId]
            )
        }
    }

    // MARK: - Daily entries

    /// `CycleDao.kt:28-29`. Update-by-id or insert, for the `(profile_id, date)` unique index —
    /// see the file header.
    public func upsertDailyEntry(_ entry: CycleDailyEntryRecord) async throws {
        try await database.writer.write { db in
            try Self.writeEntry(db, entry)
        }
    }

    /// One day's log, if the user recorded one (`CycleDao.kt:31-32`), keyed by the columns the
    /// unique `(profile_id, date)` index covers.
    public func getDailyEntry(profileId: String, epochDay: Int) async throws -> CycleDailyEntryRecord? {
        try await database.reader.read { db in
            try CycleDailyEntryRecord.fetchOne(
                db,
                sql: "SELECT * FROM cycle_daily_entries WHERE profile_id = ? AND date = ?",
                arguments: [profileId, epochDay]
            )
        }
    }

    /// One profile's logged days over a span, both bounds included, earliest first — what the
    /// calendar month reads (`CycleDao.kt:34-45`).
    public func observeDailyEntries(
        profileId: String,
        fromEpochDay: Int,
        untilEpochDay: Int
    ) -> AsyncThrowingStream<[CycleDailyEntryRecord], any Error> {
        let observation = ValueObservation.tracking { db in
            try CycleDailyEntryRecord.fetchAll(
                db,
                sql: """
                SELECT * FROM cycle_daily_entries
                WHERE profile_id = ? AND date BETWEEN ? AND ?
                ORDER BY date ASC
                """,
                arguments: [profileId, fromEpochDay, untilEpochDay]
            )
        }
        return conflatedStream(observation.values(in: database.reader))
    }

    /// The entry and the complete set of its symptom links, written together.
    ///
    /// iOS-only (divergence (a)): Android's repository issues the upsert and the link replacement
    /// as two separate writes, so a reader between them can see the new day beside the symptom set
    /// of its previous version. Here they share one `write` block. The semantics are otherwise
    /// Android's — upsert the entry, then *replace* its links rather than merge into them.
    public func saveDailyEntry(_ entry: CycleDailyEntryRecord, links: [CycleEntrySymptomRecord]) async throws {
        try await database.writer.write { db in
            try Self.writeEntry(db, entry)
            try Self.replaceEntrySymptoms(db, entryId: entry.id, links: links)
        }
    }

    // MARK: - Symptom catalog

    /// `CycleDao.kt:47-48` — how the seeded catalog is written, and how a symptom the user added
    /// joins it.
    public func upsertSymptoms(_ symptoms: [SymptomRecord]) async throws {
        try await database.writer.write { db in
            for symptom in symptoms {
                try symptom.upsert(db)
            }
        }
    }

    /// The whole catalog, seeded rows before custom ones and each half alphabetical by key
    /// (`CycleDao.kt:50-51`). No `profile_id`: the catalog is global.
    public func observeSymptoms() -> AsyncThrowingStream<[SymptomRecord], any Error> {
        let observation = ValueObservation.tracking { db in
            try SymptomRecord.fetchAll(db, sql: "SELECT * FROM symptoms ORDER BY is_custom ASC, name_key ASC")
        }
        return conflatedStream(observation.values(in: database.reader))
    }

    /// `CycleDao.kt:72-73` — what the seeding step reads to decide whether the catalog is already
    /// there. An empty table counts 0; `COUNT(*)` always returns a row, so the coalesce is a
    /// formality the compiler asks for rather than a case that happens.
    public func countSymptoms() async throws -> Int {
        try await database.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM symptoms") ?? 0
        }
    }

    // MARK: - Entry ↔ symptom links

    /// `CycleDao.kt:53-54`. The primary key is `(entry_id, symptom_id)`, so re-upserting a pair
    /// updates its severity instead of adding a second row for the same symptom.
    public func upsertEntrySymptoms(_ links: [CycleEntrySymptomRecord]) async throws {
        try await database.writer.write { db in
            for link in links {
                try link.upsert(db)
            }
        }
    }

    /// `CycleDao.kt:56-57`. No `ORDER BY` in the Kotlin — an order the source does not promise is
    /// not one to invent here, and a caller that needs one sorts.
    public func getEntrySymptoms(entryId: String) async throws -> [CycleEntrySymptomRecord] {
        try await database.reader.read { db in
            try CycleEntrySymptomRecord.fetchAll(
                db,
                sql: "SELECT * FROM cycle_entry_symptoms WHERE entry_id = ?",
                arguments: [entryId]
            )
        }
    }

    /// `CycleDao.kt:59-60`.
    public func deleteEntrySymptoms(entryId: String) async throws {
        try await database.writer.write { db in
            try Self.deleteEntrySymptoms(db, entryId: entryId)
        }
    }

    /// One entry's symptom set, replaced (`CycleDao.kt:75-81`).
    ///
    /// Room's `@Transaction` around delete-then-upsert; the `isNotEmpty` guard skips the upsert but
    /// never the delete, so unticking every symptom of a day leaves that day with none rather than
    /// with what it had.
    public func replaceEntrySymptoms(entryId: String, links: [CycleEntrySymptomRecord]) async throws {
        try await database.writer.write { db in
            try Self.replaceEntrySymptoms(db, entryId: entryId, links: links)
        }
    }

    // MARK: - Shared writes

    /// `CycleDao.kt:28-29`, written once and run from two places: `upsertDailyEntry`'s own write
    /// and the head of `saveDailyEntry`, which cannot call the public one because that would open
    /// a second write inside the transaction. Named `writeEntry` rather than after either caller:
    /// `saveDailyEntry` is the public member that writes the entry *and its links*, and two
    /// members of one type must not share a name under different meanings.
    private static func writeEntry(_ db: Database, _ entry: CycleDailyEntryRecord) throws {
        try entry.save(db)
    }

    /// `CycleDao.kt:59-60`, written once and run from two places: the statement of its own and the
    /// head of `replaceEntrySymptoms`.
    private static func deleteEntrySymptoms(_ db: Database, entryId: String) throws {
        try db.execute(sql: "DELETE FROM cycle_entry_symptoms WHERE entry_id = ?", arguments: [entryId])
    }

    /// `CycleDao.kt:75-81`, written once and run from two places: the transaction of its own and
    /// the tail of `saveDailyEntry`, which cannot call the public one because that would open a
    /// second write inside the transaction.
    private static func replaceEntrySymptoms(
        _ db: Database,
        entryId: String,
        links: [CycleEntrySymptomRecord]
    ) throws {
        try deleteEntrySymptoms(db, entryId: entryId)
        // Kotlin guards the upsert with `if (links.isNotEmpty())`; iterating an empty array is the
        // same no-op, so the guard is the loop rather than a branch that can never differ.
        for link in links {
            try link.upsert(db)
        }
    }
}
