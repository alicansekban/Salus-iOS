// Ported from the `duplicate intake log occurrence violates unique index` case of
// `core/database/src/test/kotlin/com/alicansekban/salus/core/database/DaoSmokeTest.kt:102-118`,
// plus the filtering, ordering and observation halves Android leaves to Turbine and to the SQL
// itself — and the two behaviours that have no Kotlin twin at all: the empty `keepIds` list and
// the single-transaction `saveWithSchedules`.
//
// The medication, stock and schedule queries live here; the four intake-log query members are
// `MedicationIntakeLogDaoTests`, and the fixtures both suites read are `MedicationFixtures`.
// One suite over all 23 members would not fit SwiftLint's file and type-body budgets, and the
// DAO's own table boundary is the honest place to cut.

import Foundation
import GRDB
import SalusTesting
import Testing

@testable import SalusDatabase

@Suite("MedicationDao")
struct MedicationDaoTests {
    private let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_700_000_000))

    /// `DaoSmokeTest.kt:102-118`, verbatim: `insertIntakeLog` is Room's `OnConflictStrategy.ABORT`,
    /// so a second row for the same `(schedule_id, scheduled_date, scheduled_minutes)` occurrence
    /// fails the unique index instead of replacing what is there.
    @Test("duplicate intake log occurrence violates unique index")
    func duplicateIntakeLogOccurrenceViolatesUniqueIndex() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await dao.upsert(MedicationFixtures.medication(id: "m1"))
        try await dao.upsertSchedules([MedicationFixtures.schedule(id: "s1", medicationId: "m1")])
        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(id: "log1", scheduleId: "s1"))

        var thrown = false
        do {
            // Same occurrence with a different primary key must be rejected.
            try await dao.insertIntakeLog(MedicationFixtures.intakeLog(id: "log2", scheduleId: "s1"))
        } catch let error as DatabaseError {
            thrown = error.resultCode == .SQLITE_CONSTRAINT
        }

        #expect(thrown)
        #expect(try await dao.getIntakeLogById("log2") == nil)
    }

    // MARK: - Medications

    /// `MedicationDao.kt:26-27` — one profile's active medications, alphabetically by name rather
    /// than in the order they were written.
    @Test("observeActive lists one profile's active medications ordered by name")
    func observeActiveListsActiveMedicationsOrderedByName() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await dao.upsert(MedicationFixtures.medication(id: "c", name: "C vitamini"))
        try await dao.upsert(MedicationFixtures.medication(id: "a", name: "Aspirin"))
        try await dao.upsert(MedicationFixtures.medication(id: "b", name: "B12"))
        try await dao.upsert(MedicationFixtures.medication(id: "inactive", name: "AAA", isActive: false))
        try await dao.upsert(MedicationFixtures.medication(
            id: "other-profile",
            name: "AAB",
            profileId: SalusDatabase.defaultProfileId
        ))

        var iterator = dao.observeActive(profileId: "p1").makeAsyncIterator()

        let items = try #require(try await iterator.next())
        #expect(items.map(\.id) == ["a", "b", "c"])
    }

    /// The stream re-runs its query on every transaction that touches the table, the way the Room
    /// `Flow` it ports does (`MedicationDao.kt:26-27`).
    @Test("observeActive emits again after a write")
    func observeActiveEmitsAgainAfterAWrite() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await dao.upsert(MedicationFixtures.medication(id: "m1"))

        var iterator = dao.observeActive(profileId: "p1").makeAsyncIterator()
        #expect(try await iterator.next()?.map(\.id) == ["m1"])

        try await dao.upsert(MedicationFixtures.medication(id: "m2", name: "Zinko"))
        #expect(try await iterator.next()?.map(\.id) == ["m1", "m2"])
    }

    /// `MedicationDao.kt:84-85` — the same query as `observeActive`, read once.
    @Test("getActive returns one profile's active medications ordered by name")
    func getActiveReturnsActiveMedicationsOrderedByName() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await dao.upsert(MedicationFixtures.medication(id: "z", name: "Zinko"))
        try await dao.upsert(MedicationFixtures.medication(id: "a", name: "Aspirin"))
        try await dao.upsert(MedicationFixtures.medication(id: "inactive", name: "AAA", isActive: false))
        try await dao.upsert(MedicationFixtures.medication(
            id: "other-profile",
            name: "AAB",
            profileId: SalusDatabase.defaultProfileId
        ))

        #expect(try await dao.getActive(profileId: "p1").map(\.id) == ["a", "z"])
    }

    /// `MedicationDao.kt:23-24` and `:29-30` — the row by id, whether or not it is active, and
    /// nothing once it is gone (which is what closes the detail screen).
    @Test("observeById emits the row, its update, and nil once it is deleted")
    func observeByIdEmitsRowUpdateAndNil() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await dao.upsert(MedicationFixtures.medication(id: "m1", name: "Vitamin D"))

        var iterator = dao.observeById("m1").makeAsyncIterator()

        let first = try #require(try await iterator.next())
        #expect(first?.name == "Vitamin D")

        try await dao.upsert(MedicationFixtures.medication(id: "m1", name: "Vitamin D3"))
        let updated = try #require(try await iterator.next())
        #expect(updated?.name == "Vitamin D3")

        try await dao.deleteById("m1")
        let deleted = try #require(try await iterator.next())
        #expect(deleted == nil)
    }

    @Test("getById answers nil for an id that is not there")
    func getByIdAnswersNilForAnUnknownId() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)

        #expect(try await dao.getById("nope") == nil)
    }

    /// `MedicationDao.kt:81-82` — `medication_schedules.medication_id` and
    /// `medication_intake_logs.schedule_id` are cascading foreign keys, so deleting the medication
    /// takes its schedules and their intake logs with it.
    @Test("deleteById cascades to the medication's schedules and their intake logs")
    func deleteByIdCascadesToSchedulesAndIntakeLogs() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await dao.upsert(MedicationFixtures.medication(id: "m1"))
        try await dao.upsertSchedules([MedicationFixtures.schedule(id: "s1", medicationId: "m1")])
        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(id: "log1", scheduleId: "s1"))

        try await dao.deleteById("m1")

        #expect(try await dao.getById("m1") == nil)
        #expect(try await dao.getScheduleById("s1") == nil)
        #expect(try await dao.getIntakeLogById("log1") == nil)
    }

    /// `MedicationDao.kt:138-139` — the flag and the timestamp move together, and nothing else
    /// on the row does.
    @Test("setRemindersEnabled writes the flag and the updated_at it is handed")
    func setRemindersEnabledWritesTheFlagAndUpdatedAt() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await dao.upsert(MedicationFixtures.medication(id: "m1"))
        #expect(try await dao.getById("m1")?.remindersEnabled == true)

        try await dao.setRemindersEnabled(id: "m1", enabled: false, updatedAtEpochMs: 1_788_000_000_000)

        let stored = try #require(try await dao.getById("m1"))
        #expect(stored.remindersEnabled == false)
        #expect(stored.updatedAtEpochMs == 1_788_000_000_000)
        #expect(stored.name == "Vitamin D")
    }

    // MARK: - Stock

    /// `MedicationDao.kt:129-136` — `MAX(0, stock_count - :amount)` is a floor, not a wrap: a dose
    /// larger than what is left leaves 0 rather than a negative count.
    @Test("decrementStock subtracts the amount and floors at zero")
    func decrementStockSubtractsAndFloorsAtZero() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await dao.upsert(MedicationFixtures.medication(id: "m1", stockCount: 10))

        try await dao.decrementStock(id: "m1", amount: 1.5)
        #expect(try await dao.getById("m1")?.stockCount == 8.5)

        try await dao.decrementStock(id: "m1", amount: 100)
        #expect(try await dao.getById("m1")?.stockCount == 0)
    }

    /// The `AND stock_count IS NOT NULL` half (`MedicationDao.kt:133`): "no stock tracked" is a
    /// NULL, and a dose must not turn it into a number the user never asked for.
    @Test("decrementStock leaves a medication that tracks no stock alone")
    func decrementStockLeavesNullStockAlone() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await dao.upsert(MedicationFixtures.medication(id: "m1", stockCount: nil))

        try await dao.decrementStock(id: "m1", amount: 1)

        #expect(try await dao.getById("m1")?.stockCount == nil)
    }

    // MARK: - Schedules

    /// `MedicationDao.kt:32-33` and `:35-36` — one medication's active schedules; a deactivated
    /// row is not one of them.
    @Test("observeActiveSchedulesFor and getActiveSchedulesFor skip deactivated rows")
    func activeSchedulesForSkipDeactivatedRows() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await dao.upsert(MedicationFixtures.medication(id: "m1"))
        try await dao.upsert(MedicationFixtures.medication(id: "m2", name: "Demir"))
        try await dao.upsertSchedules([
            MedicationFixtures.schedule(id: "s1", medicationId: "m1"),
            MedicationFixtures.schedule(id: "s2", medicationId: "m1", isActive: false),
            MedicationFixtures.schedule(id: "s3", medicationId: "m2")
        ])

        #expect(try await dao.getActiveSchedulesFor(medicationId: "m1").map(\.id) == ["s1"])

        var iterator = dao.observeActiveSchedulesFor(medicationId: "m1").makeAsyncIterator()
        #expect(try await iterator.next()?.map(\.id) == ["s1"])

        try await dao.upsertSchedules([MedicationFixtures.schedule(id: "s4", medicationId: "m1")])
        #expect(try await iterator.next()?.map(\.id) == ["s1", "s4"])
    }

    /// `MedicationDao.kt:38-47` and `:90-99` — the join is what scopes schedules to a profile and
    /// what drops the schedules of a deactivated medication; `medication_schedules` carries no
    /// `profile_id` and no copy of the medication's `is_active`.
    @Test("the active-schedules join excludes inactive medications, inactive schedules and other profiles")
    func activeSchedulesJoinExcludesInactiveAndOtherProfiles() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await dao.upsert(MedicationFixtures.medication(id: "active", name: "Aktif"))
        try await dao.upsert(MedicationFixtures.medication(id: "inactive-med", name: "Pasif", isActive: false))
        try await dao.upsert(MedicationFixtures.medication(
            id: "other-profile-med",
            name: "Başkası",
            profileId: SalusDatabase.defaultProfileId
        ))
        try await dao.upsertSchedules([
            MedicationFixtures.schedule(id: "kept", medicationId: "active"),
            MedicationFixtures.schedule(id: "inactive-schedule", medicationId: "active", isActive: false),
            MedicationFixtures.schedule(id: "of-inactive-med", medicationId: "inactive-med"),
            MedicationFixtures.schedule(id: "of-other-profile", medicationId: "other-profile-med")
        ])

        #expect(try await dao.getAllActiveSchedules(profileId: "p1").map(\.id) == ["kept"])

        var iterator = dao.observeAllActiveSchedules(profileId: "p1").makeAsyncIterator()
        #expect(try await iterator.next()?.map(\.id) == ["kept"])

        // Neither query carries an `ORDER BY`, so the set is what is asserted, not the sequence.
        try await dao.upsertSchedules([MedicationFixtures.schedule(id: "added", medicationId: "active")])
        #expect(try await iterator.next().map { Set($0.map(\.id)) } == ["kept", "added"])
    }

    /// `MedicationDao.kt:87-88`.
    @Test("getScheduleById answers the row, and nil for an id that is not there")
    func getScheduleByIdAnswersTheRowOrNil() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await dao.upsert(MedicationFixtures.medication(id: "m1"))
        try await dao.upsertSchedules([MedicationFixtures.schedule(id: "s1", medicationId: "m1")])

        #expect(try await dao.getScheduleById("s1")?.medicationId == "m1")
        #expect(try await dao.getScheduleById("nope") == nil)
    }

    /// `MedicationDao.kt:101-103` — deactivate instead of delete, precisely so the intake history
    /// hanging off the dropped schedule survives the edit that dropped it.
    @Test("deactivateSchedulesExcept deactivates the rest and keeps their intake history")
    func deactivateSchedulesExceptKeepsIntakeHistory() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await dao.upsert(MedicationFixtures.medication(id: "m1"))
        try await dao.upsert(MedicationFixtures.medication(id: "m2", name: "Demir"))
        try await dao.upsertSchedules([
            MedicationFixtures.schedule(id: "keep", medicationId: "m1"),
            MedicationFixtures.schedule(id: "drop", medicationId: "m1"),
            MedicationFixtures.schedule(id: "other-medication", medicationId: "m2")
        ])
        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(id: "log1", scheduleId: "drop"))

        try await dao.deactivateSchedulesExcept(medicationId: "m1", keepIds: ["keep"])

        #expect(try await dao.getActiveSchedulesFor(medicationId: "m1").map(\.id) == ["keep"])
        #expect(try await dao.getScheduleById("drop")?.isActive == false)
        #expect(try await dao.getActiveSchedulesFor(medicationId: "m2").map(\.id) == ["other-medication"])
        #expect(try await dao.getIntakeLogById("log1") != nil)
    }

    /// An empty `keepIds` deactivates every schedule of that medication — what Room's expansion of
    /// `id NOT IN (:keepIds)` over an empty list does, and what "the medication now has no
    /// schedules" has to mean. The `NOT IN` clause is dropped from the SQL in that case, so this is
    /// the test that the dropped clause did not quietly become "deactivate nothing"; another
    /// medication's schedules are untouched either way.
    @Test("deactivateSchedulesExcept with no ids to keep deactivates all of that medication's schedules")
    func deactivateSchedulesExceptWithEmptyKeepIdsDeactivatesAll() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await dao.upsert(MedicationFixtures.medication(id: "m1"))
        try await dao.upsert(MedicationFixtures.medication(id: "m2", name: "Demir"))
        try await dao.upsertSchedules([
            MedicationFixtures.schedule(id: "s1", medicationId: "m1"),
            MedicationFixtures.schedule(id: "s2", medicationId: "m1"),
            MedicationFixtures.schedule(id: "other-medication", medicationId: "m2")
        ])

        try await dao.deactivateSchedulesExcept(medicationId: "m1", keepIds: [])

        #expect(try await dao.getActiveSchedulesFor(medicationId: "m1").isEmpty)
        #expect(try await dao.getScheduleById("s1") != nil)
        #expect(try await dao.getActiveSchedulesFor(medicationId: "m2").map(\.id) == ["other-medication"])
    }

    // MARK: - saveWithSchedules

    /// The iOS-only transaction: upsert → upsert schedules → deactivate the rest, so the active
    /// schedule set is *replaced* by what the caller handed in rather than merged with it.
    @Test("saveWithSchedules writes the medication and leaves exactly the schedules it was handed active")
    func saveWithSchedulesLeavesExactlyTheHandedSchedulesActive() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await dao.saveWithSchedules(
            MedicationFixtures.medication(id: "m1"),
            schedules: [
                MedicationFixtures.schedule(id: "s1", medicationId: "m1"),
                MedicationFixtures.schedule(id: "s2", medicationId: "m1")
            ]
        )

        try await dao.saveWithSchedules(
            MedicationFixtures.medication(id: "m1", name: "Vitamin D3"),
            schedules: [MedicationFixtures.schedule(id: "s2", medicationId: "m1", timeOfDayMinutes: 1200)]
        )

        #expect(try await dao.getById("m1")?.name == "Vitamin D3")
        let active = try await dao.getActiveSchedulesFor(medicationId: "m1")
        #expect(active.map(\.id) == ["s2"])
        #expect(active.first?.timeOfDayMinutes == 1200)
        // Deactivated, not deleted: `s1`'s intake history has to outlive the edit.
        #expect(try await dao.getScheduleById("s1")?.isActive == false)
    }

    /// One `write` block, so a schedule the database refuses takes the medication down with it
    /// rather than leaving a medication with half its schedules.
    @Test("saveWithSchedules is atomic: a schedule the database refuses leaves no medication row")
    func saveWithSchedulesIsAtomic() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)

        await #expect(throws: DatabaseError.self) {
            try await dao.saveWithSchedules(
                MedicationFixtures.medication(id: "m1"),
                schedules: [
                    MedicationFixtures.schedule(id: "s1", medicationId: "m1"),
                    // A foreign key that points at no medication: SQLite rejects the row and the
                    // whole transaction rolls back with it.
                    MedicationFixtures.schedule(id: "s2", medicationId: "no-such-medication")
                ]
            )
        }

        #expect(try await dao.getById("m1") == nil)
        #expect(try await dao.getScheduleById("s1") == nil)
    }
}
