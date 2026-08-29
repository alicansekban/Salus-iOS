// `CycleDao` has no Kotlin test table to port: `DaoSmokeTest.kt` covers profiles, appointments,
// intake logs, vitals and AI summaries, and never touches `cycleDao()`. Every case below is
// therefore iOS-only, written against the SQL in
// `core/database/src/main/kotlin/com/alicansekban/salus/core/database/dao/CycleDao.kt` — the
// ordering, filtering and constraint behaviour Android leaves to Room and to the schema itself,
// plus the things that have no Kotlin twin at all: `saveDailyEntry`'s single transaction
// (divergence (a)) and the two unique-index cases the DAO answers with a `DatabaseError` where
// Room would silently write nothing (divergence (b), reasoned out in `CycleDao`'s file header).
//
// The fixtures live at the foot of this file rather than in a `CycleFixtures.swift` of their own:
// one suite reads them, so a second file would only add a hop.

import Foundation
import GRDB
import SalusCommon
import SalusTesting
import Testing

@testable import SalusDatabase

@Suite("CycleDao")
struct CycleDaoTests {
    private let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_700_000_000))

    // MARK: - Periods

    /// `CycleDao.kt:16-17` and `:22-23` — the pair the editor writes with and reads back through.
    @Test("upsertPeriod writes the row and getPeriodByStart reads it back")
    func upsertPeriodWritesTheRowAndGetPeriodByStartReadsItBack() async throws {
        let dao = try await CycleFixtures.makeDao(clock: clock)
        try await dao.upsertPeriod(CycleFixtures.period(id: "p-1", startEpochDay: 20100))

        let stored = try #require(try await dao.getPeriodByStart(profileId: "p1", startEpochDay: 20100))
        #expect(stored.id == "p-1")
        #expect(stored.endDateEpochDay == nil)
        #expect(try await dao.getPeriodByStart(profileId: "p1", startEpochDay: 20101) == nil)
        // The start date is scoped by profile, not global.
        #expect(try await dao.getPeriodByStart(
            profileId: SalusDatabase.defaultProfileId,
            startEpochDay: 20100
        ) == nil)
    }

    /// `CycleDao.kt:19-20` — `ORDER BY start_date DESC`, so the most recent period leads the list,
    /// and only that profile's rows are in it.
    @Test("observePeriods lists one profile's periods newest start first")
    func observePeriodsListsPeriodsNewestStartFirst() async throws {
        let dao = try await CycleFixtures.makeDao(clock: clock)
        try await dao.upsertPeriod(CycleFixtures.period(id: "middle", startEpochDay: 20100))
        try await dao.upsertPeriod(CycleFixtures.period(id: "oldest", startEpochDay: 20050))
        try await dao.upsertPeriod(CycleFixtures.period(id: "newest", startEpochDay: 20130))
        try await dao.upsertPeriod(CycleFixtures.period(
            id: "other-profile",
            profileId: SalusDatabase.defaultProfileId,
            startEpochDay: 20200
        ))

        var iterator = dao.observePeriods(profileId: "p1").makeAsyncIterator()

        let items = try #require(try await iterator.next())
        #expect(items.map(\.id) == ["newest", "middle", "oldest"])
    }

    /// The stream re-runs its query on every transaction that touches the table, the way the Room
    /// `Flow` it ports does (`CycleDao.kt:19-20`).
    @Test("observePeriods emits again after a write")
    func observePeriodsEmitsAgainAfterAWrite() async throws {
        let dao = try await CycleFixtures.makeDao(clock: clock)
        try await dao.upsertPeriod(CycleFixtures.period(id: "first", startEpochDay: 20100))

        var iterator = dao.observePeriods(profileId: "p1").makeAsyncIterator()
        #expect(try await iterator.next()?.map(\.id) == ["first"])

        try await dao.upsertPeriod(CycleFixtures.period(id: "second", startEpochDay: 20130))
        #expect(try await iterator.next()?.map(\.id) == ["second", "first"])
    }

    /// The unique `index_cycle_periods_profile_id_start_date`: one profile records at most one
    /// period per start day, so a second row on the same start is a constraint error rather than a
    /// silent second period. This is divergence (b) — the reason `upsertPeriod` writes through
    /// GRDB's `save` rather than its `upsert`, which would overwrite the row that is there.
    @Test("a second period on the same start date violates the unique index")
    func aSecondPeriodOnTheSameStartViolatesTheUniqueIndex() async throws {
        let dao = try await CycleFixtures.makeDao(clock: clock)
        try await dao.upsertPeriod(CycleFixtures.period(id: "p-1", startEpochDay: 20100))

        var thrown = false
        do {
            try await dao.upsertPeriod(CycleFixtures.period(id: "p-2", startEpochDay: 20100))
        } catch let error as DatabaseError {
            thrown = error.resultCode == .SQLITE_CONSTRAINT
        }

        #expect(thrown)
        #expect(try await dao.getPeriodByStart(profileId: "p1", startEpochDay: 20100)?.id == "p-1")
    }

    /// `CycleDao.kt:25-26`.
    @Test("deletePeriodById removes only that period")
    func deletePeriodByIdRemovesOnlyThatPeriod() async throws {
        let dao = try await CycleFixtures.makeDao(clock: clock)
        try await dao.upsertPeriod(CycleFixtures.period(id: "kept", startEpochDay: 20050))
        try await dao.upsertPeriod(CycleFixtures.period(id: "dropped", startEpochDay: 20100))

        try await dao.deletePeriodById("dropped")

        var iterator = dao.observePeriods(profileId: "p1").makeAsyncIterator()
        #expect(try await iterator.next()?.map(\.id) == ["kept"])
    }

    /// `CycleDao.kt:62-70` — `end_date IS NULL ORDER BY start_date DESC LIMIT 1`: the period the
    /// user is in right now is the newest one that has not been closed yet.
    @Test("getOpenPeriod answers the latest period with no end date, and nil once they are all closed")
    func getOpenPeriodAnswersTheLatestOpenPeriodOrNil() async throws {
        let dao = try await CycleFixtures.makeDao(clock: clock)
        try await dao.upsertPeriod(CycleFixtures.period(id: "closed", startEpochDay: 20050, endEpochDay: 20055))
        try await dao.upsertPeriod(CycleFixtures.period(id: "older-open", startEpochDay: 20080))
        try await dao.upsertPeriod(CycleFixtures.period(id: "newer-open", startEpochDay: 20110))
        try await dao.upsertPeriod(CycleFixtures.period(
            id: "other-profile-open",
            profileId: SalusDatabase.defaultProfileId,
            startEpochDay: 20200
        ))

        #expect(try await dao.getOpenPeriod(profileId: "p1")?.id == "newer-open")

        try await dao.upsertPeriod(CycleFixtures.period(id: "older-open", startEpochDay: 20080, endEpochDay: 20085))
        try await dao.upsertPeriod(CycleFixtures.period(id: "newer-open", startEpochDay: 20110, endEpochDay: 20115))

        #expect(try await dao.getOpenPeriod(profileId: "p1") == nil)
    }

    // MARK: - Daily entries

    /// `CycleDao.kt:28-29` and `:31-32`. The flow and mood raw values are Android-verbatim
    /// uppercase (`Cycle.kt:3-17`), and the round trip is what pins that the columns carry them
    /// unchanged.
    @Test("upsertDailyEntry writes the row and getDailyEntry reads it back")
    func upsertDailyEntryWritesTheRowAndGetDailyEntryReadsItBack() async throws {
        let dao = try await CycleFixtures.makeDao(clock: clock)
        try await dao.upsertDailyEntry(CycleFixtures.entry(
            id: "e-1",
            epochDay: 20100,
            flow: "MEDIUM",
            mood: "IRRITABLE",
            note: "Baş ağrısı"
        ))

        let stored = try #require(try await dao.getDailyEntry(profileId: "p1", epochDay: 20100))
        #expect(stored.id == "e-1")
        #expect(stored.flow == "MEDIUM")
        #expect(stored.mood == "IRRITABLE")
        #expect(stored.note == "Baş ağrısı")
        #expect(try await dao.getDailyEntry(profileId: "p1", epochDay: 20101) == nil)
        #expect(try await dao.getDailyEntry(profileId: SalusDatabase.defaultProfileId, epochDay: 20100) == nil)
    }

    /// The unique `index_cycle_daily_entries_profile_id_date`, the twin of the period one above:
    /// a profile logs at most one entry per day, so a second row on the same date is a constraint
    /// error rather than a silent overwrite. This is the other half of divergence (b).
    @Test("a second daily entry on the same date violates the unique index")
    func aSecondDailyEntryOnTheSameDateViolatesTheUniqueIndex() async throws {
        let dao = try await CycleFixtures.makeDao(clock: clock)
        try await dao.upsertDailyEntry(CycleFixtures.entry(id: "e-1", epochDay: 20100, flow: "LIGHT"))

        var thrown = false
        do {
            try await dao.upsertDailyEntry(CycleFixtures.entry(id: "e-2", epochDay: 20100, flow: "HEAVY"))
        } catch let error as DatabaseError {
            thrown = error.resultCode == .SQLITE_CONSTRAINT
        }

        #expect(thrown)
        let stored = try #require(try await dao.getDailyEntry(profileId: "p1", epochDay: 20100))
        #expect(stored.id == "e-1")
        #expect(stored.flow == "LIGHT")
    }

    /// `CycleDao.kt:34-45` — `date BETWEEN ? AND ?` includes both bounds, and `ORDER BY date ASC`
    /// is what the calendar month reads in.
    @Test("observeDailyEntries lists one profile's entries in the range, earliest day first")
    func observeDailyEntriesListsEntriesInRangeEarliestFirst() async throws {
        let dao = try await CycleFixtures.makeDao(clock: clock)
        try await dao.upsertDailyEntry(CycleFixtures.entry(id: "before", epochDay: 20099))
        try await dao.upsertDailyEntry(CycleFixtures.entry(id: "upper-bound", epochDay: 20130))
        try await dao.upsertDailyEntry(CycleFixtures.entry(id: "inside", epochDay: 20115))
        try await dao.upsertDailyEntry(CycleFixtures.entry(id: "lower-bound", epochDay: 20100))
        try await dao.upsertDailyEntry(CycleFixtures.entry(id: "after", epochDay: 20131))
        try await dao.upsertDailyEntry(CycleFixtures.entry(
            id: "other-profile",
            profileId: SalusDatabase.defaultProfileId,
            epochDay: 20115
        ))

        var iterator = dao
            .observeDailyEntries(profileId: "p1", fromEpochDay: 20100, untilEpochDay: 20130)
            .makeAsyncIterator()

        let items = try #require(try await iterator.next())
        #expect(items.map(\.id) == ["lower-bound", "inside", "upper-bound"])

        try await dao.upsertDailyEntry(CycleFixtures.entry(id: "added", epochDay: 20120))
        #expect(try await iterator.next()?.map(\.id) == ["lower-bound", "inside", "added", "upper-bound"])
    }

    // MARK: - Symptom catalog

    /// `CycleDao.kt:50-51` — `ORDER BY is_custom ASC, name_key ASC`, so the seeded catalog comes
    /// first and whatever the user added follows it, each half alphabetical by key. The query
    /// carries no `profile_id`: the catalog is global (`CycleEntity.kt:53`).
    @Test("observeSymptoms orders the catalog by is_custom then name_key")
    func observeSymptomsOrdersTheCatalogByIsCustomThenNameKey() async throws {
        let dao = try await CycleFixtures.makeDao(clock: clock)
        try await dao.upsertSymptoms([
            CycleFixtures.symptom(id: "own-b", nameKey: "symptom_custom_b", isCustom: true),
            CycleFixtures.symptom(id: "seeded-c", nameKey: "symptom_cramps"),
            CycleFixtures.symptom(id: "own-a", nameKey: "symptom_custom_a", isCustom: true),
            CycleFixtures.symptom(id: "seeded-a", nameKey: "symptom_acne")
        ])

        var iterator = dao.observeSymptoms().makeAsyncIterator()

        let items = try #require(try await iterator.next())
        #expect(items.map(\.id) == ["seeded-a", "seeded-c", "own-a", "own-b"])
    }

    /// `CycleDao.kt:72-73` — the count the seeding step reads to decide whether the catalog is
    /// already there, so the empty database has to answer 0 rather than throw.
    @Test("countSymptoms counts the whole catalog")
    func countSymptomsCountsTheWholeCatalog() async throws {
        let dao = try await CycleFixtures.makeDao(clock: clock)
        #expect(try await dao.countSymptoms() == 0)

        try await dao.upsertSymptoms([
            CycleFixtures.symptom(id: "s1", nameKey: "symptom_acne"),
            CycleFixtures.symptom(id: "s2", nameKey: "symptom_cramps"),
            CycleFixtures.symptom(id: "s3", nameKey: "symptom_custom", isCustom: true)
        ])

        #expect(try await dao.countSymptoms() == 3)
    }

    // MARK: - Entry ↔ symptom links

    /// `CycleDao.kt:53-54` and `:56-57`. The primary key is `(entry_id, symptom_id)`, so a second
    /// upsert of the same pair updates its severity instead of adding a row.
    @Test("upsertEntrySymptoms and getEntrySymptoms round-trip one entry's links")
    func upsertEntrySymptomsAndGetEntrySymptomsRoundTrip() async throws {
        let dao = try await CycleFixtures.makeDao(clock: clock)
        try await CycleFixtures.seedTwoEntriesAndSymptoms(dao)
        try await dao.upsertEntrySymptoms([
            CycleFixtures.link(entryId: "e-1", symptomId: "s1", severity: 1),
            CycleFixtures.link(entryId: "e-1", symptomId: "s2", severity: 3),
            CycleFixtures.link(entryId: "e-2", symptomId: "s1", severity: 2)
        ])

        let links = try await dao.getEntrySymptoms(entryId: "e-1")
        #expect(Set(links.map(\.symptomId)) == ["s1", "s2"])

        try await dao.upsertEntrySymptoms([CycleFixtures.link(entryId: "e-1", symptomId: "s1", severity: 3)])
        let updated = try await dao.getEntrySymptoms(entryId: "e-1")
        #expect(updated.count == 2)
        #expect(updated.first { $0.symptomId == "s1" }?.severity == 3)
    }

    /// `CycleDao.kt:59-60`.
    @Test("deleteEntrySymptoms removes only that entry's links")
    func deleteEntrySymptomsRemovesOnlyThatEntrysLinks() async throws {
        let dao = try await CycleFixtures.makeDao(clock: clock)
        try await CycleFixtures.seedTwoEntriesAndSymptoms(dao)
        try await dao.upsertEntrySymptoms([
            CycleFixtures.link(entryId: "e-1", symptomId: "s1"),
            CycleFixtures.link(entryId: "e-2", symptomId: "s1")
        ])

        try await dao.deleteEntrySymptoms(entryId: "e-1")

        #expect(try await dao.getEntrySymptoms(entryId: "e-1").isEmpty)
        #expect(try await dao.getEntrySymptoms(entryId: "e-2").map(\.symptomId) == ["s1"])
    }

    /// `CycleDao.kt:75-81` — delete then upsert, so the stored set is *replaced* by what the caller
    /// handed in rather than merged with it. The empty case is the half worth pinning: Room's
    /// `if (links.isNotEmpty())` guard skips the upsert but not the delete, so an entry whose
    /// symptoms were all unticked keeps none.
    @Test("replaceEntrySymptoms replaces the set, and empty links leave none")
    func replaceEntrySymptomsReplacesTheSetAndEmptyLinksLeaveNone() async throws {
        let dao = try await CycleFixtures.makeDao(clock: clock)
        try await CycleFixtures.seedTwoEntriesAndSymptoms(dao)
        try await dao.upsertEntrySymptoms([
            CycleFixtures.link(entryId: "e-1", symptomId: "s1"),
            CycleFixtures.link(entryId: "e-2", symptomId: "s1")
        ])

        try await dao.replaceEntrySymptoms(
            entryId: "e-1",
            links: [CycleFixtures.link(entryId: "e-1", symptomId: "s2", severity: 3)]
        )
        let replaced = try await dao.getEntrySymptoms(entryId: "e-1")
        #expect(replaced.map(\.symptomId) == ["s2"])
        #expect(replaced.first?.severity == 3)

        try await dao.replaceEntrySymptoms(entryId: "e-1", links: [])
        #expect(try await dao.getEntrySymptoms(entryId: "e-1").isEmpty)
        // Another entry's links are the other entry's business.
        #expect(try await dao.getEntrySymptoms(entryId: "e-2").map(\.symptomId) == ["s1"])
    }

    /// `cycle_entry_symptoms.entry_id` is a cascading foreign key, so a day the user cleared takes
    /// its symptom links with it rather than leaving orphans behind. `CycleDao` has no
    /// delete-entry member — Room has none either — so the delete is the raw statement a
    /// repository would issue.
    @Test("deleting a daily entry cascades to its symptom links")
    func deletingADailyEntryCascadesToItsSymptomLinks() async throws {
        let database = try await CycleFixtures.makeDatabase(clock: clock)
        let dao = CycleDao(database: database)
        try await CycleFixtures.seedTwoEntriesAndSymptoms(dao)
        try await dao.upsertEntrySymptoms([
            CycleFixtures.link(entryId: "e-1", symptomId: "s1"),
            CycleFixtures.link(entryId: "e-2", symptomId: "s1")
        ])

        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM cycle_daily_entries WHERE id = ?", arguments: ["e-1"])
        }

        #expect(try await dao.getDailyEntry(profileId: "p1", epochDay: 20100) == nil)
        #expect(try await dao.getEntrySymptoms(entryId: "e-1").isEmpty)
        #expect(try await dao.getEntrySymptoms(entryId: "e-2").map(\.symptomId) == ["s1"])
    }

    // MARK: - saveDailyEntry

    /// The iOS-only transaction (divergence (a)): the entry and the complete set of its symptom
    /// links are written together, so a reader never sees the new day beside yesterday's symptoms.
    @Test("saveDailyEntry writes the entry and replaces its links in one go")
    func saveDailyEntryWritesTheEntryAndReplacesItsLinks() async throws {
        let dao = try await CycleFixtures.makeDao(clock: clock)
        try await dao.upsertSymptoms([
            CycleFixtures.symptom(id: "s1", nameKey: "symptom_acne"),
            CycleFixtures.symptom(id: "s2", nameKey: "symptom_cramps")
        ])

        try await dao.saveDailyEntry(
            CycleFixtures.entry(id: "e-1", epochDay: 20100, flow: "LIGHT"),
            links: [CycleFixtures.link(entryId: "e-1", symptomId: "s1")]
        )
        #expect(try await dao.getDailyEntry(profileId: "p1", epochDay: 20100)?.flow == "LIGHT")
        #expect(try await dao.getEntrySymptoms(entryId: "e-1").map(\.symptomId) == ["s1"])

        try await dao.saveDailyEntry(
            CycleFixtures.entry(id: "e-1", epochDay: 20100, flow: "HEAVY", mood: "LOW"),
            links: [CycleFixtures.link(entryId: "e-1", symptomId: "s2", severity: 3)]
        )
        let stored = try #require(try await dao.getDailyEntry(profileId: "p1", epochDay: 20100))
        #expect(stored.flow == "HEAVY")
        #expect(stored.mood == "LOW")
        #expect(try await dao.getEntrySymptoms(entryId: "e-1").map(\.symptomId) == ["s2"])

        try await dao.saveDailyEntry(CycleFixtures.entry(id: "e-1", epochDay: 20100), links: [])
        #expect(try await dao.getEntrySymptoms(entryId: "e-1").isEmpty)
    }

    /// One `write` block, so a link the database refuses takes the entry down with it rather than
    /// leaving a day the user's symptoms never reached.
    @Test("saveDailyEntry is atomic: a link to an unknown symptom leaves no entry row")
    func saveDailyEntryIsAtomic() async throws {
        let dao = try await CycleFixtures.makeDao(clock: clock)
        try await dao.upsertSymptoms([CycleFixtures.symptom(id: "s1", nameKey: "symptom_acne")])

        await #expect(throws: DatabaseError.self) {
            try await dao.saveDailyEntry(
                CycleFixtures.entry(id: "e-1", epochDay: 20100),
                links: [
                    CycleFixtures.link(entryId: "e-1", symptomId: "s1"),
                    // A foreign key that points at no symptom: SQLite rejects the row and the whole
                    // transaction rolls back with it.
                    CycleFixtures.link(entryId: "e-1", symptomId: "no-such-symptom")
                ]
            )
        }

        #expect(try await dao.getDailyEntry(profileId: "p1", epochDay: 20100) == nil)
        #expect(try await dao.getEntrySymptoms(entryId: "e-1").isEmpty)
    }
}

/// One populated instance of each cycle record, with only the columns the queries filter on opened
/// up — the shape `MedicationFixtures` set.
private enum CycleFixtures {
    /// The owning profile of every period and entry below; `SalusDatabase.defaultProfileId` is
    /// already seeded by the v1 migration, so it stands in for "another profile".
    static let profile = ProfileRecord(
        id: "p1",
        displayName: "Test",
        birthDateEpochDay: nil,
        sex: nil,
        heightCm: nil,
        healthNotes: nil,
        isDefault: true,
        createdAtEpochMs: 0
    )

    static func makeDatabase(clock: any SalusClock) async throws -> SalusDatabase {
        let database = try SalusDatabase.inMemory(clock: clock)
        try await ProfileDao(database: database).upsert(profile)
        return database
    }

    static func makeDao(clock: any SalusClock) async throws -> CycleDao {
        try await CycleDao(database: makeDatabase(clock: clock))
    }

    /// Two entries — one per profile — and two symptoms, so a link can be written under either
    /// without the foreign keys getting in the way of what the test is about.
    static func seedTwoEntriesAndSymptoms(_ dao: CycleDao) async throws {
        try await dao.upsertDailyEntry(entry(id: "e-1", epochDay: 20100))
        try await dao.upsertDailyEntry(entry(id: "e-2", epochDay: 20101))
        try await dao.upsertSymptoms([
            symptom(id: "s1", nameKey: "symptom_acne"),
            symptom(id: "s2", nameKey: "symptom_cramps")
        ])
    }

    static func period(
        id: String,
        profileId: String = "p1",
        startEpochDay: Int,
        endEpochDay: Int? = nil
    ) -> CyclePeriodRecord {
        CyclePeriodRecord(
            id: id,
            profileId: profileId,
            startDateEpochDay: startEpochDay,
            endDateEpochDay: endEpochDay,
            flowPeak: "MEDIUM",
            note: nil,
            createdAtEpochMs: 0
        )
    }

    static func entry(
        id: String,
        profileId: String = "p1",
        epochDay: Int,
        flow: String? = nil,
        mood: String? = nil,
        note: String? = nil
    ) -> CycleDailyEntryRecord {
        CycleDailyEntryRecord(id: id, profileId: profileId, dateEpochDay: epochDay, flow: flow, mood: mood, note: note)
    }

    static func symptom(id: String, nameKey: String, isCustom: Bool = false) -> SymptomRecord {
        SymptomRecord(id: id, nameKey: nameKey, isCustom: isCustom, iconToken: nil)
    }

    static func link(entryId: String, symptomId: String, severity: Int = 2) -> CycleEntrySymptomRecord {
        CycleEntrySymptomRecord(entryId: entryId, symptomId: symptomId, severity: severity)
    }
}
