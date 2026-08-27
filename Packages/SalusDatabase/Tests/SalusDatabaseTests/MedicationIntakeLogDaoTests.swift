// The intake-log half of `MedicationDao` — `MedicationDao.kt:54-79` and `:105-127`.
//
// Split out of `MedicationDaoTests` (which carries the ported `DaoSmokeTest.kt` case, the
// medications and the schedules) so neither file outgrows SwiftLint's budgets; the fixtures both
// suites read are `MedicationFixtures`. Android leaves all of this to Turbine and to the SQL, so
// there is no Kotlin test to port here — only the SQL's own promises to pin.

import Foundation
import SalusTesting
import Testing

@testable import SalusDatabase

@Suite("MedicationDao intake logs")
struct MedicationIntakeLogDaoTests {
    private let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_700_000_000))

    /// `MedicationDao.kt:60-67` — one profile's recorded doses for one day, earliest dose first,
    /// re-read on every write the way the Room `Flow` it ports is.
    @Test("observeIntakeLogsForDay lists one profile's day ordered by scheduled minutes")
    func observeIntakeLogsForDayIsOrderedByScheduledMinutes() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await MedicationFixtures.seedTwoSchedules(dao)
        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(id: "evening", scheduleId: "s1", minutes: 1200))
        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(id: "morning", scheduleId: "s1", minutes: 510))
        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(id: "other-day", scheduleId: "s1", epochDay: 20101))
        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(
            id: "other-profile",
            scheduleId: "s2",
            profileId: SalusDatabase.defaultProfileId
        ))

        var iterator = dao.observeIntakeLogsForDay(profileId: "p1", epochDay: 20100).makeAsyncIterator()
        #expect(try await iterator.next()?.map(\.id) == ["morning", "evening"])

        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(id: "noon", scheduleId: "s1", minutes: 720))
        #expect(try await iterator.next()?.map(\.id) == ["morning", "noon", "evening"])
    }

    /// `MedicationDao.kt:105-115` and `:117-127` — `BETWEEN` is inclusive at both ends. Neither
    /// query carries an `ORDER BY`, so neither promises an order; the sets are what is asserted.
    @Test("the intake-log range queries include both bounds and promise no order")
    func intakeLogRangeQueriesIncludeBothBounds() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await MedicationFixtures.seedTwoSchedules(dao)
        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(id: "before", scheduleId: "s1", epochDay: 19999))
        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(id: "from", scheduleId: "s1", epochDay: 20000))
        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(id: "inside", scheduleId: "s1", epochDay: 20005))
        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(id: "to", scheduleId: "s1", epochDay: 20010))
        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(id: "after", scheduleId: "s1", epochDay: 20011))
        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(
            id: "other-profile",
            scheduleId: "s2",
            profileId: SalusDatabase.defaultProfileId,
            epochDay: 20005
        ))

        let read = try await dao.getIntakeLogsBetween(profileId: "p1", fromEpochDay: 20000, toEpochDay: 20010)
        #expect(Set(read.map(\.id)) == ["from", "inside", "to"])

        var iterator = dao.observeIntakeLogsBetween(
            profileId: "p1",
            fromEpochDay: 20000,
            toEpochDay: 20010
        ).makeAsyncIterator()
        #expect(try await iterator.next().map { Set($0.map(\.id)) } == ["from", "inside", "to"])

        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(id: "added", scheduleId: "s1", epochDay: 20006))
        #expect(try await iterator.next().map { Set($0.map(\.id)) } == ["from", "inside", "to", "added"])
    }

    /// `MedicationDao.kt:69-79` — the occurrence lookup behind "has this dose already been
    /// recorded?", keyed by exactly the columns the unique index covers.
    @Test("getIntakeLogForOccurrence finds the row for one schedule, day and minute")
    func getIntakeLogForOccurrenceFindsTheRow() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await MedicationFixtures.seedTwoSchedules(dao)
        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(id: "log1", scheduleId: "s1", minutes: 510))
        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(
            id: "log2",
            scheduleId: "s2",
            profileId: SalusDatabase.defaultProfileId,
            minutes: 510
        ))

        let found = try await dao.getIntakeLogForOccurrence(scheduleId: "s1", epochDay: 20100, minutes: 510)
        #expect(found?.id == "log1")
        #expect(try await dao.getIntakeLogForOccurrence(scheduleId: "s1", epochDay: 20100, minutes: 511) == nil)
        #expect(try await dao.getIntakeLogForOccurrence(scheduleId: "s1", epochDay: 20101, minutes: 510) == nil)
    }

    /// `MedicationDao.kt:54-55` — Room's `@Update` matches on the primary key, which is how
    /// recording a dose turns a `PENDING` row into a `TAKEN` one without touching the occurrence
    /// the unique index keys on.
    @Test("updateIntakeLog replaces the row that shares the id")
    func updateIntakeLogReplacesTheRowThatSharesTheId() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)
        try await MedicationFixtures.seedTwoSchedules(dao)
        try await dao.insertIntakeLog(MedicationFixtures.intakeLog(id: "log1", scheduleId: "s1"))

        try await dao.updateIntakeLog(MedicationFixtures.intakeLog(id: "log1", scheduleId: "s1", status: "TAKEN"))

        let stored = try #require(try await dao.getIntakeLogById("log1"))
        #expect(stored.status == "TAKEN")
        #expect(stored.scheduledMinutes == 510)
    }

    /// `MedicationDao.kt:57-58`.
    @Test("getIntakeLogById answers nil for an id that is not there")
    func getIntakeLogByIdAnswersNilForAnUnknownId() async throws {
        let dao = try await MedicationFixtures.makeDao(clock: clock)

        #expect(try await dao.getIntakeLogById("nope") == nil)
    }
}
