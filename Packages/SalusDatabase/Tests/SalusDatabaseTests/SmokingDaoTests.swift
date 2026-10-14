// Ported from `core/database/src/test/kotlin/com/alicansekban/salus/core/database/SmokingDaoTest.kt`
// (Android `2045f43`): the same cases, rows and expected values. Room's `.first()` on a `Flow`
// becomes the first value of the DAO's stream.
//
// The cases after the ported ones are iOS-only: the stream re-emitting after a write (Room's
// generated flow does that without a test of its own), GRDB's `update` throwing on a missing row
// where Room's `@Update` writes nothing (the same divergence `MedicationDao.updateIntakeLog`
// records), and the `write(_:)` transaction the repository builds its use cases on (contract §6:
// "each use case runs in one transaction").

import Foundation
import GRDB
import SalusCommon
import SalusTesting
import Testing

@testable import SalusDatabase

@Suite("SmokingDao")
struct SmokingDaoTests {
    private let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_700_000_000))

    // MARK: - Ported from SmokingDaoTest.kt

    @Test("plan round-trips every column including the nullable ones")
    func planRoundTripsEveryColumn() async throws {
        let (dao, _) = try makeDao()
        let reduce = SmokingFixtures.plan(
            "plan-1",
            mode: "REDUCE",
            dailyLimit: 8,
            reason: "Kızım için",
            notificationsEnabled: false,
            eveningReminderEnabled: true
        )
        try await dao.upsertPlan(reduce)
        #expect(try await first(dao.observePlan()) == reduce)

        let quit = SmokingFixtures.plan(
            "plan-1",
            mode: "QUIT",
            dailyLimit: nil,
            reason: nil,
            notificationsEnabled: false,
            eveningReminderEnabled: true
        )
        try await dao.upsertPlan(quit)
        #expect(try await first(dao.observePlan()) == quit)
    }

    /// Contract §8.6: writing the plan replaces any row with a different id.
    @Test("the plan table keeps a single row when a plan with another id is written")
    func planTableKeepsASingleRow() async throws {
        let (dao, database) = try makeDao()
        try await dao.upsertPlan(SmokingFixtures.plan("plan-1"))
        try await dao.upsertPlan(SmokingFixtures.plan("plan-2"))

        #expect(try await first(dao.observePlan())?.id == "plan-2")
        #expect(try await count(database, "smoking_plan") == 1)
    }

    @Test("no plan reads as nil")
    func noPlanReadsAsNil() async throws {
        let (dao, _) = try makeDao()
        #expect(try await first(dao.observePlan()) == nil)
    }

    @Test("price periods round-trip and update in place")
    func pricePeriodsRoundTripAndUpdateInPlace() async throws {
        let (dao, _) = try makeDao()
        let later = SmokingPricePeriodRecord(id: "pp-2", effectiveFromEpochDay: 20010, unitCostMinor: 450)
        let first = SmokingPricePeriodRecord(id: "pp-1", effectiveFromEpochDay: 20000, unitCostMinor: 400)
        try await dao.insertPricePeriod(later)
        try await dao.insertPricePeriod(first)
        #expect(try await self.first(dao.observePricePeriods()) == [first, later])

        let repriced = SmokingPricePeriodRecord(id: "pp-2", effectiveFromEpochDay: 20010, unitCostMinor: 500)
        try await dao.updatePricePeriod(repriced)
        #expect(try await self.first(dao.observePricePeriods()) == [first, repriced])
    }

    @Test("quit attempts round-trip and an attempt can be closed")
    func quitAttemptsRoundTripAndCanBeClosed() async throws {
        let (dao, _) = try makeDao()
        let active = SmokingFixtures.attempt("a-1", startedAtMs: 1000)
        try await dao.insertAttempt(active)
        #expect(try await first(dao.observeAttempts()) == [active])

        let closed = SmokingFixtures.attempt("a-1", startedAtMs: 1000, endedAtMs: 9000, endReason: "RESTARTED")
        try await dao.updateAttempt(closed)
        #expect(try await first(dao.observeAttempts()) == [closed])
    }

    @Test("events round-trip with and without their optional columns")
    func eventsRoundTripWithAndWithoutOptionalColumns() async throws {
        let (dao, _) = try makeDao()
        try await dao.insertAttempt(SmokingFixtures.attempt("a-1", startedAtMs: 1000))
        let smoked = SmokingFixtures.event(
            "e-1",
            occurredAtMs: 2000,
            units: 2,
            trigger: "COFFEE",
            intensity: 4,
            attemptId: "a-1"
        )
        let craving = SmokingFixtures.event(
            "e-2",
            occurredAtMs: 3000,
            type: "CRAVING_RESISTED",
            units: nil,
            trigger: nil,
            intensity: nil,
            attemptId: nil
        )
        try await dao.insertEvent(craving)
        try await dao.insertEvent(smoked)
        #expect(try await first(dao.observeEvents()) == [smoked, craving])

        let edited = SmokingFixtures.event(
            "e-1",
            occurredAtMs: 2000,
            units: 3,
            trigger: "STRESS",
            intensity: 4,
            attemptId: "a-1"
        )
        try await dao.updateEvent(edited)
        try await dao.deleteEvent(id: "e-2")
        #expect(try await first(dao.observeEvents()) == [edited])
    }

    /// `ON DELETE SET NULL` on `smoking_event.attempt_id` (contract §1).
    @Test("deleting an attempt detaches its events instead of deleting them")
    func deletingAnAttemptDetachesItsEvents() async throws {
        let (dao, database) = try makeDao()
        try await dao.insertAttempt(SmokingFixtures.attempt("a-1", startedAtMs: 1000))
        try await dao.insertEvent(SmokingFixtures.event("e-1", occurredAtMs: 2000, attemptId: "a-1"))

        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM smoking_quit_attempt WHERE id = 'a-1'")
        }

        let events = try await first(dao.observeEvents())
        #expect(events.map(\.id) == ["e-1"])
        #expect(events.first?.attemptId == nil)
    }

    @Test("deleteZeroMarker removes only that day's zero-unit rows")
    func deleteZeroMarkerRemovesOnlyThatDaysZeroUnitRows() async throws {
        let (dao, _) = try makeDao()
        let day: Int64 = 20000
        try await dao.insertEvent(SmokingFixtures.event("marker", occurredAtMs: 1000, epochDay: day, units: 0))
        try await dao.insertEvent(SmokingFixtures.event("smoked-same-day", occurredAtMs: 2000, epochDay: day, units: 1))
        try await dao.insertEvent(SmokingFixtures.event(
            "craving-same-day",
            occurredAtMs: 3000,
            type: "CRAVING_RESISTED",
            epochDay: day,
            units: nil
        ))
        try await dao.insertEvent(SmokingFixtures.event(
            "marker-other-day",
            occurredAtMs: 4000,
            epochDay: day + 1,
            units: 0
        ))

        try await dao.deleteZeroMarker(epochDay: day)

        #expect(try await first(dao.observeEvents()).map(\.id) == [
            "smoked-same-day",
            "craving-same-day",
            "marker-other-day"
        ])
    }

    /// Contract §8.6: the active goal is the newest row, achieved or not.
    @Test("the active goal is the most recently created one, achieved or not")
    func activeGoalIsTheMostRecentlyCreatedOne() async throws {
        let (dao, _) = try makeDao()
        #expect(try await first(dao.observeActiveGoal()) == nil)

        let older = SmokingSavingsGoalRecord(
            id: "g-1",
            title: "Bisiklet",
            targetMinor: 500_000,
            createdAtMs: 1000,
            achievedAtMs: nil
        )
        try await dao.upsertGoal(older)
        #expect(try await first(dao.observeActiveGoal()) == older)

        let achieved = SmokingSavingsGoalRecord(
            id: "g-1",
            title: "Bisiklet",
            targetMinor: 500_000,
            createdAtMs: 1000,
            achievedAtMs: 5000
        )
        try await dao.upsertGoal(achieved)
        #expect(try await first(dao.observeActiveGoal()) == achieved)

        let newer = SmokingSavingsGoalRecord(
            id: "g-2",
            title: "Tatil",
            targetMinor: 500_000,
            createdAtMs: 6000,
            achievedAtMs: nil
        )
        try await dao.upsertGoal(newer)
        #expect(try await first(dao.observeActiveGoal()) == newer)
    }

    @Test("resetAll empties all five smoking tables")
    func resetAllEmptiesAllFiveTables() async throws {
        let (dao, database) = try makeDao()
        try await dao.upsertPlan(SmokingFixtures.plan("plan-1"))
        try await dao.insertPricePeriod(SmokingPricePeriodRecord(
            id: "pp-1",
            effectiveFromEpochDay: 1,
            unitCostMinor: 1
        ))
        try await dao.insertAttempt(SmokingFixtures.attempt("a-1", startedAtMs: 1000))
        try await dao.insertEvent(SmokingFixtures.event("e-1", occurredAtMs: 2000, attemptId: "a-1"))
        try await dao.upsertGoal(SmokingSavingsGoalRecord(
            id: "g-1",
            title: "t",
            targetMinor: 1,
            createdAtMs: 1,
            achievedAtMs: nil
        ))

        try await dao.resetAll()

        for table in SmokingFixtures.tables {
            #expect(try await count(database, table) == 0, "rows left in \(table)")
        }
    }

    // MARK: - iOS-only

    /// The stream re-runs its query on every write to the table, the way Room's `Flow` does.
    @Test("observeEvents emits again after a write")
    func observeEventsEmitsAgainAfterAWrite() async throws {
        let (dao, _) = try makeDao()
        var iterator = dao.observeEvents().makeAsyncIterator()
        #expect(try await iterator.next()?.isEmpty == true)

        try await dao.insertEvent(SmokingFixtures.event("e-1", occurredAtMs: 2000))
        #expect(try await iterator.next()?.map(\.id) == ["e-1"])
    }

    /// Room's `@Insert` aborts on a taken primary key; GRDB's `insert` does the same.
    @Test("inserting an event under a taken id throws")
    func insertingAnEventUnderATakenIdThrows() async throws {
        let (dao, _) = try makeDao()
        try await dao.insertEvent(SmokingFixtures.event("e-1", occurredAtMs: 2000))
        await #expect(throws: DatabaseError.self) {
            try await dao.insertEvent(SmokingFixtures.event("e-1", occurredAtMs: 3000))
        }
    }

    /// The divergence `MedicationDao.updateIntakeLog` records, in the same safe direction: Room's
    /// `@Update` writes nothing for a missing id, GRDB's throws `RecordError.recordNotFound`.
    @Test("updating an event that is not there throws")
    func updatingAMissingEventThrows() async throws {
        let (dao, _) = try makeDao()
        await #expect(throws: RecordError.self) {
            try await dao.updateEvent(SmokingFixtures.event("missing", occurredAtMs: 2000))
        }
    }

    /// "+1 replaces the zero marker" (Task 6) as one transaction: the reads inside see the
    /// transaction's own writes, and the outside world sees both writes or neither.
    @Test("write runs its body as one transaction that reads its own writes")
    func writeRunsItsBodyAsOneTransaction() async throws {
        let (dao, _) = try makeDao()
        try await dao.insertEvent(SmokingFixtures.event("marker", occurredAtMs: 1000, units: 0))

        let seen = try await dao.write { tx in
            try tx.deleteZeroMarker(epochDay: 20000)
            try tx.insertEvent(SmokingFixtures.event("smoked", occurredAtMs: 2000))
            return try tx.events().map(\.id)
        }

        #expect(seen == ["smoked"])
        #expect(try await first(dao.observeEvents()).map(\.id) == ["smoked"])
    }

    @Test("a write whose body throws leaves nothing behind")
    func aThrowingWriteRollsBack() async throws {
        let (dao, _) = try makeDao()
        try await dao.insertEvent(SmokingFixtures.event("marker", occurredAtMs: 1000, units: 0))

        await #expect(throws: DatabaseError.self) {
            try await dao.write { tx in
                try tx.deleteZeroMarker(epochDay: 20000)
                try tx.upsertPlan(SmokingFixtures.plan("plan-1"))
                // A taken primary key: the insert aborts, and the two writes before it with it.
                try tx.insertEvent(SmokingFixtures.event("smoked", occurredAtMs: 2000))
                try tx.insertEvent(SmokingFixtures.event("smoked", occurredAtMs: 3000))
            }
        }

        #expect(try await first(dao.observeEvents()).map(\.id) == ["marker"])
        #expect(try await first(dao.observePlan()) == nil)
    }

    /// The transaction's reads answer with the same queries and order as the streams, so a use
    /// case deciding inside a transaction sees what the screen sees.
    @Test("the transaction reads agree with the streams")
    func transactionReadsAgreeWithTheStreams() async throws {
        let (dao, _) = try makeDao()
        try await dao.upsertPlan(SmokingFixtures.plan("plan-1"))
        try await dao.insertPricePeriod(SmokingPricePeriodRecord(
            id: "pp-2",
            effectiveFromEpochDay: 20010,
            unitCostMinor: 450
        ))
        try await dao.insertPricePeriod(SmokingPricePeriodRecord(
            id: "pp-1",
            effectiveFromEpochDay: 20000,
            unitCostMinor: 400
        ))
        try await dao.insertAttempt(SmokingFixtures.attempt("a-2", startedAtMs: 5000))
        try await dao.insertAttempt(SmokingFixtures.attempt("a-1", startedAtMs: 1000))
        try await dao.insertEvent(SmokingFixtures.event("e-2", occurredAtMs: 3000))
        try await dao.insertEvent(SmokingFixtures.event("e-1", occurredAtMs: 2000))
        try await dao.upsertGoal(SmokingSavingsGoalRecord(
            id: "g-1", title: "a", targetMinor: 1, createdAtMs: 1, achievedAtMs: 2
        ))
        try await dao.upsertGoal(SmokingSavingsGoalRecord(
            id: "g-2", title: "b", targetMinor: 1, createdAtMs: 3, achievedAtMs: nil
        ))

        let read = try await dao.write { tx in
            try SmokingTables(
                plan: tx.plan(),
                pricePeriods: tx.pricePeriods(),
                attempts: tx.attempts(),
                events: tx.events(),
                activeGoal: tx.activeGoal()
            )
        }

        #expect(read.plan == SmokingFixtures.plan("plan-1"))
        #expect(read.pricePeriods.map(\.id) == ["pp-1", "pp-2"])
        #expect(read.attempts.map(\.id) == ["a-1", "a-2"])
        #expect(read.events.map(\.id) == ["e-1", "e-2"])
        #expect(read.activeGoal?.id == "g-2")
        #expect(try await first(dao.observePricePeriods()) == read.pricePeriods)
        #expect(try await first(dao.observeAttempts()) == read.attempts)
        #expect(try await first(dao.observeEvents()) == read.events)
        #expect(try await first(dao.observeActiveGoal()) == read.activeGoal)
    }

    // MARK: - Helpers

    private func makeDao() throws -> (SmokingDao, SalusDatabase) {
        let database = try SalusDatabase.inMemory(clock: clock)
        return (SmokingDao(database: database), database)
    }

    /// Room's `Flow.first()`.
    private func first<Value: Sendable>(_ stream: AsyncThrowingStream<Value, any Error>) async throws -> Value {
        var iterator = stream.makeAsyncIterator()
        return try #require(try await iterator.next())
    }

    private func count(_ database: SalusDatabase, _ table: String) async throws -> Int {
        try await database.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") ?? -1
        }
    }
}

/// Everything the transaction read, carried out of the `write` block in one `Sendable` value.
private struct SmokingTables: Sendable {
    let plan: SmokingPlanRecord?
    let pricePeriods: [SmokingPricePeriodRecord]
    let attempts: [SmokingQuitAttemptRecord]
    let events: [SmokingEventRecord]
    let activeGoal: SmokingSavingsGoalRecord?
}

/// `SmokingDaoTest.kt`'s `plan` / `attempt` / `event` builders, same defaults. Parameters stand in
/// for Kotlin's `.copy(...)`, so the records themselves stay immutable.
enum SmokingFixtures {
    static let tables = [
        "smoking_plan",
        "smoking_price_period",
        "smoking_quit_attempt",
        "smoking_event",
        "smoking_savings_goal"
    ]

    static func plan(
        _ id: String,
        mode: String = "QUIT",
        dailyLimit: Int? = nil,
        reason: String? = nil,
        notificationsEnabled: Bool = true,
        eveningReminderEnabled: Bool = false
    ) -> SmokingPlanRecord {
        SmokingPlanRecord(
            id: id,
            mode: mode,
            productType: "CIGARETTE",
            baselineUnitsPerDay: 20,
            dailyLimit: dailyLimit,
            currencyCode: "TRY",
            reason: reason,
            notificationsEnabled: notificationsEnabled,
            eveningReminderEnabled: eveningReminderEnabled,
            createdAtMs: 1000,
            tzId: "Europe/Istanbul"
        )
    }

    static func attempt(
        _ id: String,
        startedAtMs: Int64,
        endedAtMs: Int64? = nil,
        endReason: String? = nil
    ) -> SmokingQuitAttemptRecord {
        SmokingQuitAttemptRecord(
            id: id,
            startedAtMs: startedAtMs,
            tzId: "Europe/Istanbul",
            endedAtMs: endedAtMs,
            endReason: endReason
        )
    }

    static func event(
        _ id: String,
        occurredAtMs: Int64,
        type: String = "SMOKED",
        epochDay: Int64 = 20000,
        units: Int? = 1,
        trigger: String? = nil,
        intensity: Int? = nil,
        attemptId: String? = nil
    ) -> SmokingEventRecord {
        SmokingEventRecord(
            id: id,
            type: type,
            occurredAtMs: occurredAtMs,
            tzId: "Europe/Istanbul",
            epochDay: epochDay,
            units: units,
            trigger: trigger,
            intensity: intensity,
            productType: "CIGARETTE",
            attemptId: attemptId
        )
    }
}
