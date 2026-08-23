// Android has no unit test for `ReminderAlarmDao` itself — the engine tests
// (`core/reminder/src/test/.../ReminderWindowSynchronizerTest.kt`) run against the in-memory
// `FakeReminderAlarmDao` of `Fakes.kt`, so the SQL is only ever exercised on a device. These
// cases pin the real SQL instead: the fake's `filter`/`sortedBy` predicates (`Fakes.kt:37`,
// `Fakes.kt:64`) are the behaviour the queries have to reproduce.
//
// The fixture is `SalusDatabase.inMemory`, as in `VitalsDaoTests`. `reminder_alarms` has no
// foreign key (`ReminderAlarmEntity.kt`), so no profile row is needed here.

import Foundation
import GRDB
import SalusTesting
import Testing

@testable import SalusDatabase

@Suite("ReminderAlarmDao")
struct ReminderAlarmDaoTests {
    private let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_700_000_000))

    /// `ReminderAlarmDao.kt:11-12` — `@Upsert` keys on the primary key, so re-syncing the same
    /// occurrence rewrites its row rather than growing the ledger.
    @Test("upsert of the same id replaces the row instead of adding one")
    func upsertOfSameIdReplacesRow() async throws {
        let dao = try makeDao()
        try await dao.upsert(Self.alarm(id: "a1", triggerAt: 1000, requestCode: 1))
        try await dao.upsert(Self.alarm(id: "a1", triggerAt: 2000, requestCode: 1))

        let rows = try await dao.getByEntity(type: "MEDICATION_DOSE", entityId: "sched-1")
        #expect(rows.count == 1)
        #expect(rows.first?.triggerAtEpochMs == 2000)
    }

    /// `ReminderAlarmEntity.kt:13` — `request_code` is a unique index because on Android it is the
    /// `PendingIntent` request code, and two alarms sharing one would silently replace each other.
    /// The index has to reject the second row rather than let the ledger lie about it.
    @Test("a second row with an already-taken request code is rejected")
    func duplicateRequestCodeIsRejected() async throws {
        let dao = try makeDao()
        try await dao.upsert(Self.alarm(id: "a1", triggerAt: 1000, requestCode: 7))

        var thrown: DatabaseError?
        do {
            try await dao.upsert(Self.alarm(id: "a2", triggerAt: 2000, requestCode: 7))
        } catch let error as DatabaseError {
            thrown = error
        }

        #expect(thrown?.extendedResultCode == .SQLITE_CONSTRAINT_UNIQUE)
    }

    /// `ReminderAlarmDao.kt:14-15` — the scheduler's working set: `SCHEDULED` only, soonest first.
    /// Everything that already fired, was missed or was cancelled stays out of it.
    @Test("getScheduled returns scheduled rows only, soonest first")
    func getScheduledReturnsScheduledRowsSoonestFirst() async throws {
        let dao = try makeDao()
        try await dao.upsert(Self.alarm(id: "later", triggerAt: 3000, requestCode: 1))
        try await dao.upsert(Self.alarm(id: "sooner", triggerAt: 1000, requestCode: 2))
        try await dao.upsert(Self.alarm(id: "fired", triggerAt: 2000, requestCode: 3, state: "FIRED"))
        try await dao.upsert(Self.alarm(id: "missed", triggerAt: 2000, requestCode: 4, state: "MISSED"))
        try await dao.upsert(
            Self.alarm(id: "cancelled", triggerAt: 2000, requestCode: 5, state: "CANCELLED")
        )

        let rows = try await dao.getScheduled()

        #expect(rows.map(\.id) == ["sooner", "later"])
    }

    /// `ReminderAlarmDao.kt:17-18` — both halves of the key filter, so one schedule's alarms are
    /// not another's and an appointment sharing an entity id is a different row.
    @Test("getByEntity answers for one type and one entity only")
    func getByEntityFiltersByTypeAndEntity() async throws {
        let dao = try makeDao()
        try await dao.upsert(Self.alarm(id: "mine", triggerAt: 1000, requestCode: 1))
        try await dao.upsert(
            Self.alarm(id: "other-entity", triggerAt: 1000, requestCode: 2, entityId: "sched-2")
        )
        try await dao.upsert(
            Self.alarm(id: "other-type", triggerAt: 1000, requestCode: 3, type: "APPOINTMENT")
        )

        let rows = try await dao.getByEntity(type: "MEDICATION_DOSE", entityId: "sched-1")

        #expect(rows.map(\.id) == ["mine"])
    }

    /// `ReminderAlarmDao.kt:20-27` — the occurrence key is the third part of the identity, and a
    /// key nothing was materialized for answers nothing.
    @Test("getByOccurrence finds the row for one occurrence key and nothing for an unknown one")
    func getByOccurrenceFindsTheOccurrence() async throws {
        let dao = try makeDao()
        try await dao.upsert(Self.alarm(id: "a1", triggerAt: 1000, requestCode: 1))
        try await dao.upsert(
            Self.alarm(id: "a2", triggerAt: 2000, requestCode: 2, occurrenceKey: "2026-09-02T08:00")
        )

        let found = try await dao.getByOccurrence(
            type: "MEDICATION_DOSE",
            entityId: "sched-1",
            occurrenceKey: "2026-09-02T08:00"
        )
        let missing = try await dao.getByOccurrence(
            type: "MEDICATION_DOSE",
            entityId: "sched-1",
            occurrenceKey: "2026-09-03T08:00"
        )

        #expect(found?.id == "a2")
        #expect(missing == nil)
    }

    /// `ReminderAlarmDao.kt:29-30` — the lookup a fired alarm arrives with: the OS hands back the
    /// request code and nothing else.
    @Test("getByRequestCode finds the row for a request code and nothing for an unknown one")
    func getByRequestCodeFindsTheRow() async throws {
        let dao = try makeDao()
        try await dao.upsert(Self.alarm(id: "a1", triggerAt: 1000, requestCode: 11))

        #expect(try await dao.getByRequestCode(11)?.id == "a1")
        #expect(try await dao.getByRequestCode(12) == nil)
    }

    /// `ReminderAlarmDao.kt:32-33`, driven by `HandleFiredAlarmUseCase.kt:22` and
    /// `ReminderWindowSynchronizer.kt:53` — the two transitions that take a row out of the
    /// scheduler's working set.
    @Test("updateState moves a row to FIRED and to MISSED, and out of getScheduled")
    func updateStateTransitionsTheRow() async throws {
        let dao = try makeDao()
        try await dao.upsert(Self.alarm(id: "fired", triggerAt: 1000, requestCode: 1))
        try await dao.upsert(Self.alarm(id: "missed", triggerAt: 2000, requestCode: 2))

        try await dao.updateState(id: "fired", newState: "FIRED")
        try await dao.updateState(id: "missed", newState: "MISSED")

        #expect(try await dao.getByRequestCode(1)?.state == "FIRED")
        #expect(try await dao.getByRequestCode(2)?.state == "MISSED")
        #expect(try await dao.getScheduled().isEmpty)
    }

    /// `ReminderAlarmDao.kt:35-36` — deleting a medication schedule takes its whole ledger with
    /// it, and nobody else's.
    @Test("deleteByEntity removes one entity's rows only")
    func deleteByEntityRemovesOneEntitysRows() async throws {
        let dao = try makeDao()
        try await dao.upsert(Self.alarm(id: "mine-1", triggerAt: 1000, requestCode: 1))
        try await dao.upsert(Self.alarm(id: "mine-2", triggerAt: 2000, requestCode: 2))
        try await dao.upsert(
            Self.alarm(id: "other", triggerAt: 3000, requestCode: 3, entityId: "sched-2")
        )

        try await dao.deleteByEntity(type: "MEDICATION_DOSE", entityId: "sched-1")

        #expect(try await dao.getByEntity(type: "MEDICATION_DOSE", entityId: "sched-1").isEmpty)
        #expect(try await dao.getByEntity(type: "MEDICATION_DOSE", entityId: "sched-2").count == 1)
    }

    /// `ReminderAlarmDao.kt:38-39` (`Fakes.kt:64`) — pruning is for finished history: a `SCHEDULED`
    /// row survives however old it is, and the bound is strict, so a row sitting exactly on it
    /// stays too.
    @Test("purgeFinishedBefore deletes finished rows strictly older than the bound only")
    func purgeFinishedBeforeDeletesFinishedRowsOnly() async throws {
        let dao = try makeDao()
        try await dao.upsert(Self.alarm(id: "old-fired", triggerAt: 999, requestCode: 1, state: "FIRED"))
        try await dao.upsert(
            Self.alarm(id: "on-bound-fired", triggerAt: 1000, requestCode: 2, state: "FIRED")
        )
        try await dao.upsert(
            Self.alarm(id: "old-cancelled", triggerAt: 500, requestCode: 3, state: "CANCELLED")
        )
        try await dao.upsert(Self.alarm(id: "old-scheduled", triggerAt: 1, requestCode: 4))

        try await dao.purgeFinishedBefore(1000)

        let remaining = try await dao.getByEntity(type: "MEDICATION_DOSE", entityId: "sched-1")
        #expect(Set(remaining.map(\.id)) == ["on-bound-fired", "old-scheduled"])
    }

    private func makeDao() throws -> ReminderAlarmDao {
        try ReminderAlarmDao(database: SalusDatabase.inMemory(clock: clock))
    }

    /// `SampleRecords.reminderAlarm`, with the fields the queries filter on opened up so a test
    /// can write the row a query is supposed to skip.
    private static func alarm(
        id: String,
        triggerAt: Int64,
        requestCode: Int,
        type: String = "MEDICATION_DOSE",
        entityId: String = "sched-1",
        occurrenceKey: String = "2026-09-01T08:00",
        state: String = "SCHEDULED"
    ) -> ReminderAlarmRecord {
        ReminderAlarmRecord(
            id: id,
            type: type,
            entityId: entityId,
            occurrenceKey: occurrenceKey,
            triggerAtEpochMs: triggerAt,
            requestCode: requestCode,
            state: state
        )
    }
}
