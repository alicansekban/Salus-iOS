// Covers `data/MedicationsRepositoryImpl.swift`.
//
// There is no `MedicationRepositoryImplTest.kt` to port — Android tests the repository only
// through the ViewModels — so every case here is iOS-only, and each one pins a fact the Kotlin
// implementation states in a comment rather than in a test: that a save preserves `created_at`,
// `color_token` and the reminders toggle; that a save is a *replace* of the active schedule set;
// that `upsertLog` merges on the `(schedule, day, minutes)` triple rather than on the row id; that
// deleting a medication takes its schedules and their recorded doses with it.
//
// The database is the **real** one over `SalusDatabase.inMemory`, which is the template's
// RepositoryImpl standard and the shape `AppointmentsRepositoryImplTests` set: the facts above are
// facts about real SQL, real foreign keys and a real transaction, and a fake DAO would only prove
// the fake.
//
// Deterministic by construction: a `FixedSalusClock`, rows seeded before an observation starts, and
// every emission read by awaiting the stream rather than by sleeping.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel
import SalusTesting
import Testing

@testable import FeatureMedications

@Suite("MedicationsRepositoryImpl")
struct MedicationsRepositoryImplTests {
    private static let now = Date(timeIntervalSince1970: 1_755_000_000)
    private static let nowEpochMs: Int64 = 1_755_000_000_000

    @Test("saveMedication stores the medication with its active schedules")
    func saveMedicationStoresTheMedicationWithItsActiveSchedules() async throws {
        let fixture = try Self.makeFixture()

        try await fixture.repository.saveMedication(testMedication(), schedules: [testSchedule()])

        let stored = try #require(try await fixture.repository.getMedication(id: "med-1"))
        #expect(stored.medication == testMedication())
        #expect(stored.schedules == [testSchedule()])
        let record = try #require(try await fixture.dao.getById("med-1"))
        #expect(record.profileId == SalusDatabase.defaultProfileId)
        #expect(record.colorToken == "primary")
        #expect(record.createdAtEpochMs == Self.nowEpochMs)
        #expect(record.updatedAtEpochMs == Self.nowEpochMs)
    }

    /// The three fields the editor never sends and so must never overwrite. `created_at` keeps an
    /// edited medication from reading as new, `color_token` is picked elsewhere, and
    /// `reminders_enabled` has one write path — `setRemindersEnabled`.
    @Test("saveMedication keeps createdAt, colorToken and remindersEnabled on an edit")
    func saveMedicationKeepsCreatedAtColorTokenAndRemindersEnabledOnAnEdit() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveMedication(testMedication(), schedules: [testSchedule()])
        let created = try #require(try await fixture.dao.getById("med-1"))
        try await fixture.dao.upsert(Self.recolored(created))
        try await fixture.repository.setRemindersEnabled(medicationId: "med-1", enabled: false)

        let later = Self.now.addingTimeInterval(3600)
        fixture.clock.advanceTo(later)
        // A stale editor form: it carries the flag's *old* value, which the save must not write.
        try await fixture.repository.saveMedication(
            testMedication(name: "Aspirin Forte", remindersEnabled: true),
            schedules: [testSchedule()]
        )

        let record = try #require(try await fixture.dao.getById("med-1"))
        #expect(record.name == "Aspirin Forte")
        #expect(record.createdAtEpochMs == Self.nowEpochMs)
        #expect(record.updatedAtEpochMs == later.epochMilliseconds)
        #expect(record.colorToken == "accent-3")
        #expect(record.remindersEnabled == false)
    }

    /// The save replaces the active schedule set rather than merging into it — and *deactivates*
    /// the dropped slot instead of deleting it, so the doses recorded against it survive the edit.
    @Test("saveMedication deactivates the schedules an edit dropped, keeping their logs")
    func saveMedicationDeactivatesTheSchedulesAnEditDropped() async throws {
        let fixture = try Self.makeFixture()
        let evening = testSchedule(id: "sch-2", timeOfDayMinutes: 20 * 60)
        try await fixture.repository.saveMedication(testMedication(), schedules: [testSchedule(), evening])
        try await fixture.repository.upsertLog(testLog(scheduleId: "sch-2", epochDay: 100, minuteOfDay: 20 * 60))

        try await fixture.repository.saveMedication(testMedication(), schedules: [testSchedule()])

        let stored = try #require(try await fixture.repository.getMedication(id: "med-1"))
        #expect(stored.schedules.map(\.id) == ["sch-1"])
        #expect(try await fixture.repository.getSchedule(scheduleId: "sch-2")?.isActive == false)
        #expect(try await fixture.repository.getLogsBetween(fromEpochDay: 100, toEpochDay: 100).count == 1)
    }

    @Test("getAllActiveMedications groups the profile's schedules by medication")
    func getAllActiveMedicationsGroupsTheProfilesSchedulesByMedication() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveMedication(testMedication(), schedules: [testSchedule()])
        try await fixture.repository.saveMedication(
            testMedication(id: "med-2", name: "Metformin"),
            schedules: []
        )
        try await fixture.repository.saveMedication(
            testMedication(id: "med-3", name: "Stopped", isActive: false),
            schedules: [testSchedule(id: "sch-3", medicationId: "med-3")]
        )

        let all = try await fixture.repository.getAllActiveMedications()

        #expect(all.map(\.medication.id) == ["med-1", "med-2"])
        #expect(all.first?.schedules.map(\.id) == ["sch-1"])
        #expect(all.last?.schedules.isEmpty == true)
    }

    /// The combine half of `observeActiveMedications`: one profile-wide schedule observation serves
    /// the whole list, so a mis-grouping would hand one medication another's dose slots.
    @Test(
        "observeActiveMedications emits medications with their own schedules and regroups after a write",
        .timeLimit(.minutes(1))
    )
    func observeActiveMedicationsEmitsMedicationsWithTheirOwnSchedules() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveMedication(testMedication(), schedules: [testSchedule()])

        var iterator = fixture.repository.observeActiveMedications().makeAsyncIterator()
        let first = try #require(try await iterator.next())
        #expect(first.map(\.medication.id) == ["med-1"])
        #expect(first.first?.schedules.map(\.id) == ["sch-1"])

        try await fixture.repository.saveMedication(
            testMedication(id: "med-2", name: "Metformin"),
            schedules: [testSchedule(id: "sch-2", medicationId: "med-2")]
        )

        // Bounded rather than "drain until it matches": a regression that stops regrouping has to
        // fail the assertion, not hang the suite. Two emissions is the most the write can produce
        // — one per observation — and the intermediate one is a real `combine` state, the new
        // medication paired with the schedule set as it was a moment ago, so the loop settles on
        // the *second* rather than on the first pair that has two medications.
        var latest = first
        for _ in 0 ..< 2 {
            guard let emitted = try await iterator.next() else { break }
            latest = emitted
            if emitted.last?.schedules.map(\.id) == ["sch-2"] {
                break
            }
        }
        #expect(latest.map(\.medication.id) == ["med-1", "med-2"])
        #expect(latest.first?.schedules.map(\.id) == ["sch-1"])
        #expect(latest.last?.schedules.map(\.id) == ["sch-2"])
    }

    /// The nil emission is what closes the detail screen when the medication it is showing is
    /// deleted, so it is the one emission that must not be swallowed.
    @Test(
        "observeMedication emits the medication with its schedules, then nil once it is gone",
        .timeLimit(.minutes(1))
    )
    func observeMedicationEmitsTheMedicationThenNilOnceItIsGone() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveMedication(testMedication(), schedules: [testSchedule()])

        var iterator = fixture.repository.observeMedication(id: "med-1").makeAsyncIterator()
        let first = try #require(try await iterator.next())
        #expect(first?.medication == testMedication())
        #expect(first?.schedules == [testSchedule()])

        try await fixture.repository.deleteMedication(id: "med-1")

        var latest = first
        for _ in 0 ..< 2 {
            guard let emitted = try await iterator.next() else { break }
            latest = emitted
            if emitted == nil {
                break
            }
        }
        #expect(latest == nil)
    }

    /// The `(schedule, day, minutes)` triple is the true identity, not the row id: a dose recorded
    /// from a notification and the same dose edited on Home carry different ids and must land on
    /// one row. Without the lookup the second write would hit the unique index and throw.
    @Test("upsertLog merges by the schedule, day and minutes triple rather than by id")
    func upsertLogMergesByTheScheduleDayAndMinutesTriple() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveMedication(testMedication(), schedules: [testSchedule()])
        try await fixture.repository.upsertLog(
            testLog(id: "from-notification", epochDay: 100, status: .taken, doseAmount: 1.0)
        )

        try await fixture.repository.upsertLog(
            testLog(id: "from-the-ui", epochDay: 100, status: .skipped, doseAmount: 2.0)
        )

        let stored = try #require(
            try await fixture.repository.getLog(scheduleId: "sch-1", epochDay: 100, minuteOfDay: 8 * 60)
        )
        #expect(stored.id == "from-notification")
        #expect(stored.status == .skipped)
        #expect(stored.doseAmount == 2.0)
        #expect(try await fixture.repository.getLogsBetween(fromEpochDay: 100, toEpochDay: 100).count == 1)
    }

    /// Both bounds included, and a day outside the span left out.
    @Test("getLogsBetween returns the span inclusively", .timeLimit(.minutes(1)))
    func getLogsBetweenReturnsTheSpanInclusively() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveMedication(testMedication(), schedules: [testSchedule()])
        for day in 99 ... 102 {
            try await fixture.repository.upsertLog(testLog(id: "log-\(day)", epochDay: day))
        }

        let logs = try await fixture.repository.getLogsBetween(fromEpochDay: 100, toEpochDay: 101)

        #expect(Set(logs.map(\.epochDay)) == [100, 101])

        var iterator = fixture.repository.observeLogsBetween(fromEpochDay: 100, toEpochDay: 101)
            .makeAsyncIterator()
        let observed = try #require(try await iterator.next())
        #expect(Set(observed.map(\.epochDay)) == [100, 101])
    }

    /// The foreign keys are what make this one statement: the medication cascades to its schedules,
    /// which cascade to the doses recorded against them.
    @Test("deleteMedication cascades to schedules and their logs")
    func deleteMedicationCascadesToSchedulesAndTheirLogs() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveMedication(testMedication(), schedules: [testSchedule()])
        try await fixture.repository.upsertLog(testLog(epochDay: 100))

        try await fixture.repository.deleteMedication(id: "med-1")

        #expect(try await fixture.repository.getMedication(id: "med-1") == nil)
        #expect(try await fixture.repository.getSchedule(scheduleId: "sch-1") == nil)
        #expect(try await fixture.repository.getLogsBetween(fromEpochDay: 100, toEpochDay: 100).isEmpty)
    }

    @Test("decrementStock floors at zero and stamps the toggle write with the clock")
    func decrementStockFloorsAtZeroAndSetRemindersEnabledStampsTheClock() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveMedication(
            testMedication(stockCount: 3.0, stockThreshold: 1.0),
            schedules: [testSchedule()]
        )

        try await fixture.repository.decrementStock(medicationId: "med-1", amount: 10.0)
        let later = Self.now.addingTimeInterval(3600)
        fixture.clock.advanceTo(later)
        try await fixture.repository.setRemindersEnabled(medicationId: "med-1", enabled: false)

        let stored = try #require(try await fixture.repository.getMedication(id: "med-1"))
        #expect(stored.medication.stockCount == 0.0)
        #expect(stored.medication.remindersEnabled == false)
        #expect(try await fixture.dao.getById("med-1")?.updatedAtEpochMs == later.epochMilliseconds)
    }

    /// The profile scoping is real, not decorative: a repository pointed at another profile sees
    /// none of this one's rows.
    @Test("the repository reads only its own profile")
    func theRepositoryReadsOnlyItsOwnProfile() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveMedication(testMedication(), schedules: [testSchedule()])
        try await fixture.repository.upsertLog(testLog(epochDay: 100))

        let other = MedicationsRepositoryImpl(dao: fixture.dao, clock: fixture.clock, profileId: "someone-else")

        #expect(try await other.getAllActiveMedications().isEmpty)
        #expect(try await other.getLogsBetween(fromEpochDay: 100, toEpochDay: 100).isEmpty)
    }

    /// `color_token` is written by the medication editor's colour picker, which is not this task's
    /// code; the test reaches past the repository to plant a non-default value so the preservation
    /// assertion has something to preserve.
    private static func recolored(_ record: MedicationRecord) -> MedicationRecord {
        MedicationRecord(
            id: record.id,
            profileId: record.profileId,
            name: record.name,
            form: record.form,
            strengthValue: record.strengthValue,
            strengthUnit: record.strengthUnit,
            colorToken: "accent-3",
            instructions: record.instructions,
            stockCount: record.stockCount,
            stockThreshold: record.stockThreshold,
            startDateEpochDay: record.startDateEpochDay,
            endDateEpochDay: record.endDateEpochDay,
            isActive: record.isActive,
            remindersEnabled: record.remindersEnabled,
            createdAtEpochMs: record.createdAtEpochMs,
            updatedAtEpochMs: record.updatedAtEpochMs
        )
    }

    private static func makeFixture() throws -> (
        repository: MedicationsRepositoryImpl,
        dao: MedicationDao,
        clock: FixedSalusClock
    ) {
        let clock = FixedSalusClock(now: now)
        let dao = try MedicationDao(database: SalusDatabase.inMemory(clock: clock))
        let repository = MedicationsRepositoryImpl(
            dao: dao,
            clock: clock,
            profileId: SalusDatabase.defaultProfileId
        )
        return (repository, dao, clock)
    }
}
