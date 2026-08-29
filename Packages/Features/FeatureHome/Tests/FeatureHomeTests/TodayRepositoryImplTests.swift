// Covers `data/TodayRepositoryImpl.swift`.
//
// There is no `TodayRepositoryImplTest.kt` to port — Android tests the repository only through
// `HomeViewModelTest` over a fake `TodayRepository`, and covers the join itself in
// `TodayDoseAssemblerTest` — so **every case here is iOS-only**. What they pin is the part the
// assembler test cannot see: the four DAO observations composed into one `TodayOverview`, and the
// three derivations the Kotlin states in `TodayRepositoryImpl.kt:65-120` rather than in a test —
// the cycle-day window, the average-gap filter, the appointment cap and the 30-day weight window.
//
// The database is the **real** one over `SalusDatabase.inMemory`, which is the template's
// RepositoryImpl standard: `WHERE profile_id = ? AND starts_at_epoch_ms >= ?`, `ORDER BY`, and the
// `BETWEEN` of the weight window are facts about real SQL, and a fake DAO would only prove the
// fake. `SalusDatabase.defaultProfileId` is already seeded by the v1 migration, so no profile row
// has to be written first.
//
// Deterministic by construction: a `FixedSalusClock`, every row written before the observation
// starts, and the emission read by awaiting the stream rather than by sleeping. `today` and `now`
// are read back off the same clock the repository captures, so no epoch day is hardcoded.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel
import SalusSettings
import SalusTesting
import Testing

@testable import FeatureHome

@Suite("TodayRepositoryImpl")
struct TodayRepositoryImplTests {
    /// The doses come from `TodayDoseAssembler`, which has its own ported table; what this pins is
    /// that the three medication observations reach it with the captured `today` **and
    /// `nowMinute`**. The fixture's instant is 12:00 UTC = 15:00 in `Europe/Istanbul`, so
    /// `nowMinute` is 900: the 08:00 slot is an hour past its grace window and the 20:00 slot has
    /// not come round yet. A repository that passed the wrong minute — zero, or a per-emission
    /// reading — could not produce both statuses at once.
    @Test("the overview carries today's doses with their resolved statuses", .timeLimit(.minutes(1)))
    func theOverviewCarriesTodaysDosesWithTheirResolvedStatuses() async throws {
        let fixture = try Fixture()
        #expect(fixture.clock.minuteOfDayNow() == 900)
        try await fixture.medicationDao.upsert(medicationRecord(id: "med-1", name: "Aspirin"))
        try await fixture.medicationDao.upsertSchedules([
            scheduleRecord(id: "sch-1", medicationId: "med-1", minutes: 480),
            scheduleRecord(id: "sch-2", medicationId: "med-1", minutes: 1200)
        ])

        let overview = try await fixture.firstOverview()

        #expect(overview.doses.map(\.scheduleId) == ["sch-1", "sch-2"])
        #expect(overview.doses.map(\.status) == [.missed, .pending])
        let dose = try #require(overview.doses.first)
        #expect(dose.medicationId == "med-1")
        #expect(dose.medicationName == "Aspirin")
        #expect(dose.minuteOfDay == 480)
        #expect(dose.doseAmount == 1.0)
    }

    /// The heart of plan ruling 3: `today` / `nowMinute` / `nowMs` are captured **once, when the
    /// observation is created**, never per emission. A live stream therefore keeps reporting the
    /// day it started on however long it runs, and re-subscribing is the *only* thing that moves
    /// it — which is exactly what `HomeRoute`'s `.task` does on every appearance, the iOS twin of
    /// Android's `WhileSubscribed(5_000)`.
    ///
    /// The second medication starts *tomorrow*, so it is invisible to an observation captured
    /// today. What forces the second emission is a recorded dose, and it is chosen for three
    /// reasons: it writes **one table in one transaction**, so exactly one further emission
    /// arrives; that table is one of the dose join's own three sources, so the join genuinely
    /// re-runs rather than replaying a cached list; and the log is only found at all because the
    /// log query was bound to the *captured* day. So `.taken` proves the join re-ran, and the
    /// still-single dose proves the day did not move under the collector.
    @Test("today and now are captured once, when the observation starts", .timeLimit(.minutes(1)))
    func todayAndNowAreCapturedOnceWhenTheObservationStarts() async throws {
        let fixture = try Fixture()
        let capturedToday = fixture.today
        try await fixture.medicationDao.saveWithSchedules(
            medicationRecord(id: "med-today", name: "Aspirin"),
            schedules: [scheduleRecord(id: "sch-today", medicationId: "med-today", minutes: 480)]
        )
        try await fixture.medicationDao.saveWithSchedules(
            medicationRecord(id: "med-tomorrow", name: "Betaserc", start: capturedToday + 1),
            schedules: [scheduleRecord(id: "sch-tomorrow", medicationId: "med-tomorrow", minutes: 600)]
        )

        var iterator = fixture.repository.observeTodayOverview().makeAsyncIterator()
        let first = try #require(try await iterator.next())
        #expect(first.doses.map(\.scheduleId) == ["sch-today"])
        #expect(first.doses.map(\.status) == [.missed])

        fixture.clock.advanceTo(fixture.clock.now().addingTimeInterval(24 * 60 * 60))
        #expect(fixture.today == capturedToday + 1)
        try await fixture.medicationDao.insertIntakeLog(
            intakeLogRecord(scheduleId: "sch-today", medicationId: "med-today", day: capturedToday, minutes: 480)
        )

        let second = try #require(try await iterator.next())
        // The log was found under the captured day, so the join really re-ran...
        #expect(second.doses.map(\.status) == [.taken])
        // ...and tomorrow's medication is still out of its window.
        #expect(second.doses.map(\.scheduleId) == ["sch-today"])

        // Only a new subscription re-captures the day.
        let resubscribed = try await fixture.firstOverview()
        #expect(resubscribed.doses.map(\.scheduleId) == ["sch-today", "sch-tomorrow"])
    }

    /// `today - start + 1`, 1-based: a period that started eleven days ago is cycle day twelve.
    @Test("the cycle day counts from the latest recorded start", .timeLimit(.minutes(1)))
    func theCycleDayCountsFromTheLatestRecordedStart() async throws {
        let fixture = try Fixture()
        try await fixture.cycleDao.upsertPeriod(periodRecord(
            id: "older",
            start: fixture.today - 40,
            end: fixture.today - 35
        ))
        try await fixture.cycleDao.upsertPeriod(periodRecord(
            id: "latest",
            start: fixture.today - 11,
            end: fixture.today - 6
        ))

        let overview = try await fixture.firstOverview()

        #expect(overview.cycle.cycleDay == 12)
        #expect(overview.cycle.isPeriodOpen == false)
    }

    /// `MAX_MEANINGFUL_CYCLE_DAY = 60`, and the bound is inclusive: day 60 still reads, day 61 is
    /// dropped to `nil` because the number stops being informative rather than because it is wrong.
    @Test("a cycle day past sixty stops being reported", .timeLimit(.minutes(1)))
    func aCycleDayPastSixtyStopsBeingReported() async throws {
        let onTheBound = try Fixture()
        try await onTheBound.cycleDao.upsertPeriod(periodRecord(id: "p", start: onTheBound.today - 59))
        #expect(try await onTheBound.firstOverview().cycle.cycleDay == 60)

        let pastTheBound = try Fixture()
        try await pastTheBound.cycleDao.upsertPeriod(periodRecord(id: "p", start: pastTheBound.today - 60))
        #expect(try await pastTheBound.firstOverview().cycle.cycleDay == nil)
    }

    /// `isPeriodOpen` is a fact about the *latest* period only — an earlier one left without an end
    /// date does not keep the flag on.
    @Test("isPeriodOpen follows the latest period's end date", .timeLimit(.minutes(1)))
    func isPeriodOpenFollowsTheLatestPeriodsEndDate() async throws {
        let fixture = try Fixture()
        try await fixture.cycleDao.upsertPeriod(periodRecord(id: "open", start: fixture.today - 2))

        #expect(try await fixture.firstOverview().cycle.isPeriodOpen == true)

        try await fixture.cycleDao.upsertPeriod(periodRecord(id: "open", start: fixture.today - 2, end: fixture.today))

        #expect(try await fixture.firstOverview().cycle.isPeriodOpen == false)
    }

    /// Gaps of 28 and 30 days average to 29. The mean is integer and **truncating**, matching
    /// Kotlin's `sum() / size` on `Int`.
    @Test("the average cycle length is the truncating mean of the usable gaps", .timeLimit(.minutes(1)))
    func theAverageCycleLengthIsTheTruncatingMeanOfTheUsableGaps() async throws {
        let fixture = try Fixture()
        let first = fixture.today - 70
        try await fixture.cycleDao.upsertPeriod(periodRecord(id: "p1", start: first))
        try await fixture.cycleDao.upsertPeriod(periodRecord(id: "p2", start: first + 28))
        try await fixture.cycleDao.upsertPeriod(periodRecord(id: "p3", start: first + 58))

        #expect(try await fixture.firstOverview().cycle.averageCycleLengthDays == 29)
    }

    /// A gap outside `21...45` is data noise, and a run with no usable gap has no average at all —
    /// `nil`, never a zero the dashboard would draw as an empty progress bar.
    @Test("a gap outside the usable range leaves no average", .timeLimit(.minutes(1)))
    func aGapOutsideTheUsableRangeLeavesNoAverage() async throws {
        let fixture = try Fixture()
        let first = fixture.today - 70
        try await fixture.cycleDao.upsertPeriod(periodRecord(id: "p1", start: first))
        try await fixture.cycleDao.upsertPeriod(periodRecord(id: "p2", start: first + 60))

        #expect(try await fixture.firstOverview().cycle.averageCycleLengthDays == nil)
    }

    /// `MAX_APPOINTMENTS = 3`, applied to the DAO's `starts_at_epoch_ms ASC`, so the three that
    /// survive are the soonest three.
    @Test("upcoming appointments are capped at the soonest three", .timeLimit(.minutes(1)))
    func upcomingAppointmentsAreCappedAtTheSoonestThree() async throws {
        let fixture = try Fixture()
        for index in 1 ... 4 {
            try await fixture.appointmentDao.upsert(
                appointmentRecord(
                    id: "appt-\(index)",
                    title: "Visit \(index)",
                    startsAtEpochMs: fixture.nowMs + Int64(index) * 3_600_000
                )
            )
        }

        let overview = try await fixture.firstOverview()

        #expect(overview.appointments.map(\.id) == ["appt-1", "appt-2", "appt-3"])
        let first = try #require(overview.appointments.first)
        #expect(first.title == "Visit 1")
        #expect(first.doctorName == "Dr. Demir")
        #expect(first.timeZoneId == "Europe/Istanbul")
    }

    /// `WEIGHT_TREND_WINDOW = 30 days`, oldest → newest, every reading in the window and no cap.
    /// The reading outside the window still counts as the latest weight — the window clips the
    /// sparkline, not the headline number.
    @Test("the weight trend holds only the last thirty days, oldest first", .timeLimit(.minutes(1)))
    func theWeightTrendHoldsOnlyTheLastThirtyDaysOldestFirst() async throws {
        let fixture = try Fixture()
        try await fixture.vitalsDao.upsert(vitalsRecord(
            id: "w-old",
            type: .weight,
            at: fixture.nowMs - 31 * dayMs,
            primary: 70
        ))
        try await fixture.vitalsDao.upsert(vitalsRecord(
            id: "w-mid",
            type: .weight,
            at: fixture.nowMs - 29 * dayMs,
            primary: 71
        ))
        try await fixture.vitalsDao.upsert(vitalsRecord(
            id: "w-new",
            type: .weight,
            at: fixture.nowMs - dayMs,
            primary: 72.5
        ))

        let overview = try await fixture.firstOverview()

        #expect(overview.vitals.weightTrend == [71, 72.5])
        #expect(overview.vitals.latestWeightKg == 72.5)
    }

    /// The three `observeLatest` sources and the preference, in one emission: the glucose value
    /// stays the stored mg/dL number and only the unit follows the setting, which is what lets the
    /// screen convert once at the point of display.
    @Test("the latest readings and the glucose unit come from their own sources", .timeLimit(.minutes(1)))
    func theLatestReadingsAndTheGlucoseUnitComeFromTheirOwnSources() async throws {
        let fixture = try Fixture()
        try await fixture.vitalsDao.upsert(
            vitalsRecord(
                id: "bp",
                type: .bloodPressure,
                at: fixture.nowMs - dayMs,
                primary: 118,
                secondary: 76,
                unit: "mmHg"
            )
        )
        try await fixture.vitalsDao.upsert(
            vitalsRecord(id: "glu", type: .bloodGlucose, at: fixture.nowMs - dayMs, primary: 95, unit: "mg/dL")
        )
        fixture.preferences.setGlucoseUnit(.mmolL)

        let overview = try await fixture.firstOverview()

        #expect(overview.vitals.latestSystolic == 118)
        #expect(overview.vitals.latestDiastolic == 76)
        #expect(overview.vitals.latestGlucoseMgdl == 95)
        #expect(overview.vitals.glucoseUnit == .mmolL)
    }

    /// Nothing recorded is still an overview: `cycle` and `vitals` are non-optional, so the screen
    /// draws its empty lines rather than branching on a missing snapshot.
    @Test("an empty database still emits an overview", .timeLimit(.minutes(1)))
    func anEmptyDatabaseStillEmitsAnOverview() async throws {
        let fixture = try Fixture()

        let overview = try await fixture.firstOverview()

        #expect(overview.doses.isEmpty)
        #expect(overview.appointments.isEmpty)
        #expect(overview.cycle == CycleSnapshot(cycleDay: nil, isPeriodOpen: false, averageCycleLengthDays: nil))
        #expect(overview.vitals.weightTrend.isEmpty)
        #expect(overview.vitals.latestWeightKg == nil)
        #expect(overview.vitals.glucoseUnit == .mgDl)
    }

    /// A throwaway suite, an in-memory database and the repository over both. A class rather than a
    /// struct because `deinit` is the only teardown hook that fires whether the test passed, failed
    /// or threw — `CycleReminderSettingsImplTests`' `Fixture`, and `TestUserDefaults`' reason.
    private final class Fixture {
        let suiteName: String
        let defaults: UserDefaults
        let clock: FixedSalusClock
        let medicationDao: MedicationDao
        let appointmentDao: AppointmentDao
        let cycleDao: CycleDao
        let vitalsDao: VitalsDao
        let preferences: SalusPreferencesDataSource
        let repository: TodayRepositoryImpl

        /// The day and the instant the repository captures, read off the same clock so no epoch
        /// day is hardcoded into an expectation.
        var today: Int { clock.todayEpochDay() }
        var nowMs: Int64 { clock.nowEpochMilliseconds() }

        init() throws {
            let suiteName = "salus-home-repo-test-\(UUID().uuidString)"
            self.suiteName = suiteName
            defaults = try #require(
                UserDefaults(suiteName: suiteName),
                "UserDefaults refused the suite name \(suiteName)"
            )
            let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_755_000_000))
            self.clock = clock
            let database = try SalusDatabase.inMemory(clock: clock)
            medicationDao = MedicationDao(database: database)
            appointmentDao = AppointmentDao(database: database)
            cycleDao = CycleDao(database: database)
            vitalsDao = VitalsDao(database: database)
            let preferences = SalusPreferencesDataSource(
                defaults: defaults,
                appLockFlagStore: InMemoryAppLockFlagStore()
            )
            self.preferences = preferences
            repository = TodayRepositoryImpl(
                medicationDao: medicationDao,
                appointmentDao: appointmentDao,
                cycleDao: cycleDao,
                vitalsDao: vitalsDao,
                preferences: preferences,
                clock: clock,
                profileId: SalusDatabase.defaultProfileId
            )
        }

        /// The first joined emission — the point at which all four (and the vitals stream's five)
        /// observations have produced a value.
        func firstOverview() async throws -> TodayOverview {
            var iterator = repository.observeTodayOverview().makeAsyncIterator()
            return try #require(try await iterator.next())
        }

        deinit {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
}

// MARK: - Record builders

private let dayMs: Int64 = 86_400_000

private func medicationRecord(id: String, name: String, start: Int = 0) -> MedicationRecord {
    MedicationRecord(
        id: id,
        profileId: SalusDatabase.defaultProfileId,
        name: name,
        form: "TABLET",
        strengthValue: nil,
        strengthUnit: nil,
        colorToken: "primary",
        instructions: nil,
        stockCount: nil,
        stockThreshold: nil,
        startDateEpochDay: start,
        endDateEpochDay: nil,
        isActive: true,
        remindersEnabled: true,
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0
    )
}

private func scheduleRecord(id: String, medicationId: String, minutes: Int = 480) -> MedicationScheduleRecord {
    MedicationScheduleRecord(
        id: id,
        medicationId: medicationId,
        recurrence: Recurrence.daily.rawValue,
        daysOfWeekMask: 0,
        intervalDays: nil,
        anchorDateEpochDay: 0,
        timeOfDayMinutes: minutes,
        doseAmount: 1.0,
        isActive: true
    )
}

private func periodRecord(id: String, start: Int, end: Int? = nil) -> CyclePeriodRecord {
    CyclePeriodRecord(
        id: id,
        profileId: SalusDatabase.defaultProfileId,
        startDateEpochDay: start,
        endDateEpochDay: end,
        flowPeak: nil,
        note: nil,
        createdAtEpochMs: 0
    )
}

private func appointmentRecord(id: String, title: String, startsAtEpochMs: Int64) -> AppointmentRecord {
    AppointmentRecord(
        id: id,
        profileId: SalusDatabase.defaultProfileId,
        title: title,
        doctorName: "Dr. Demir",
        specialty: nil,
        location: nil,
        notes: nil,
        startsAtLocal: "2025-08-12T10:00",
        timeZoneId: "Europe/Istanbul",
        startsAtEpochMs: startsAtEpochMs,
        durationMinutes: 30,
        status: "SCHEDULED",
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0
    )
}

private func vitalsRecord(
    id: String,
    type: VitalType,
    at measuredAtEpochMs: Int64,
    primary: Double,
    secondary: Double? = nil,
    unit: String = "kg"
) -> VitalsMeasurementRecord {
    VitalsMeasurementRecord(
        id: id,
        profileId: SalusDatabase.defaultProfileId,
        type: type.rawValue,
        measuredAtEpochMs: measuredAtEpochMs,
        timeZoneId: "Europe/Istanbul",
        valuePrimary: primary,
        valueSecondary: secondary,
        valueTertiary: nil,
        unit: unit,
        measurementContext: nil,
        note: nil
    )
}

private func intakeLogRecord(
    scheduleId: String,
    medicationId: String,
    day: Int,
    minutes: Int
) -> MedicationIntakeLogRecord {
    MedicationIntakeLogRecord(
        id: "log-\(scheduleId)",
        scheduleId: scheduleId,
        medicationId: medicationId,
        profileId: SalusDatabase.defaultProfileId,
        scheduledDateEpochDay: day,
        scheduledMinutes: minutes,
        status: IntakeStatus.taken.rawValue,
        takenAtEpochMs: 0,
        snoozedUntilEpochMs: nil,
        doseAmount: 1.0,
        note: nil
    )
}
