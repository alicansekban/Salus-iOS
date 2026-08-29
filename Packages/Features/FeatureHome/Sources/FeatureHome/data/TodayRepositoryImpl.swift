// Ported 1:1 from `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/data/
// TodayRepositoryImpl.kt:29-131`. The `internal object TodayDoseAssembler` that shares that Kotlin
// file lives in `TodayDoseAssembler.swift`; see its header for why.
//
// Kotlin's `combine(a, b, c, …)` is `SalusCommon`'s `latestOfThree` / `latestOfFour` /
// `latestOfFive` plus `mapped`, which is the whole of the structural difference: those combinators
// take no transform (their argument counts are the one thing that varies), so the tuple is mapped
// afterwards instead of inside. The semantics are `combine`'s — nothing emits until every source
// has produced a value, then any source's value emits carrying the others' latest, and the first
// failure fails the join.
//
// `preferences.userSettings` is the one non-throwing source in the five-way vitals join, so it goes
// through `SalusCommon`'s `throwingStream(over:)` to be re-typed. Kotlin needs no such adapter
// because DataStore and Room both answer a `Flow`.
//
// **The type is a `struct`, and internal.** Nothing outside this module constructs it — the
// feature's module factory, which lives in this package, is its one construction site — and its
// stored properties are immutable and `Sendable`, so the protocol's `Sendable` conformance is
// checked rather than promised. `CycleRepositoryImpl`'s shape.

import SalusCommon
import SalusDatabase
import SalusModel
import SalusSettings

/// The only implementation of ``TodayRepository`` (`TodayRepositoryImpl.kt:30-131`).
struct TodayRepositoryImpl: TodayRepository {
    private let medicationDao: MedicationDao
    private let appointmentDao: AppointmentDao
    private let cycleDao: CycleDao
    private let vitalsDao: VitalsDao
    private let preferences: SalusPreferencesDataSource
    private let clock: any SalusClock
    private let profileId: String

    /// The `profileId` default is the value Koin passes at the single construction site
    /// (`HomeModule.kt`, `SalusDatabase.DEFAULT_PROFILE_ID`). It stays a parameter so a test can
    /// point the repository at another profile and prove the scoping is real.
    init(
        medicationDao: MedicationDao,
        appointmentDao: AppointmentDao,
        cycleDao: CycleDao,
        vitalsDao: VitalsDao,
        preferences: SalusPreferencesDataSource,
        clock: any SalusClock,
        profileId: String = SalusDatabase.defaultProfileId
    ) {
        self.medicationDao = medicationDao
        self.appointmentDao = appointmentDao
        self.cycleDao = cycleDao
        self.vitalsDao = vitalsDao
        self.preferences = preferences
        self.clock = clock
        self.profileId = profileId
    }

    /// `TodayRepositoryImpl.kt:42-55`.
    ///
    /// "Today" and "now" are captured **once, here, before any observation starts** — not per
    /// emission. Android's `WhileSubscribed(5_000)` on the ViewModel's `stateIn` is what
    /// re-captures them when the user comes back to the tab; the iOS twin is `HomeRoute`'s `.task`
    /// re-subscribing on every appearance (plan ruling 3). A collector that stays subscribed over
    /// midnight keeps reporting the day it started on, on both platforms.
    func observeTodayOverview() -> AsyncThrowingStream<TodayOverview, any Error> {
        let today = clock.todayEpochDay()
        let nowMinute = clock.minuteOfDayNow()
        let nowMs = clock.nowEpochMilliseconds()

        return mapped(
            latestOfFour(
                dosesStream(today: today, nowMinute: nowMinute),
                appointmentsStream(nowMs: nowMs),
                cycleStream(today: today),
                vitalsStream(nowMs: nowMs)
            )
        ) { latest in
            TodayOverview(doses: latest.0, appointments: latest.1, cycle: latest.2, vitals: latest.3)
        }
    }

    /// `TodayRepositoryImpl.kt:57-63`. The logs are read for `today` alone, both bounds the same
    /// day, because that is the only day the assembler resolves a slot against.
    private func dosesStream(today: Int, nowMinute: Int) -> AsyncThrowingStream<[TodayDose], any Error> {
        mapped(
            latestOfThree(
                medicationDao.observeActive(profileId: profileId),
                medicationDao.observeAllActiveSchedules(profileId: profileId),
                medicationDao.observeIntakeLogsBetween(profileId: profileId, fromEpochDay: today, toEpochDay: today)
            )
        ) { latest in
            TodayDoseAssembler.assemble(
                medications: latest.0,
                schedules: latest.1,
                logs: latest.2,
                today: today,
                nowMinute: nowMinute
            )
        }
    }

    /// `TodayRepositoryImpl.kt:65-76`. The DAO's `ORDER BY starts_at_epoch_ms ASC` is the order, so
    /// the three that survive the cap are the soonest three.
    private func appointmentsStream(nowMs: Int64) -> AsyncThrowingStream<[UpcomingAppointment], any Error> {
        mapped(appointmentDao.observeUpcoming(profileId: profileId, fromEpochMs: nowMs)) { records in
            records.prefix(Self.maxAppointments).map { record in
                UpcomingAppointment(
                    id: record.id,
                    title: record.title,
                    doctorName: record.doctorName,
                    startsAtEpochMs: record.startsAtEpochMs,
                    timeZoneId: record.timeZoneId
                )
            }
        }
    }

    /// `TodayRepositoryImpl.kt:78-92`.
    private func cycleStream(today: Int) -> AsyncThrowingStream<CycleSnapshot, any Error> {
        mapped(cycleDao.observePeriods(profileId: profileId)) { periods in
            Self.snapshot(of: periods, today: today)
        }
    }

    /// `TodayRepositoryImpl.kt:79-91`, as a pure function of the rows.
    ///
    /// Swift's `max(by:)` keeps the **last** of equally maximal elements and Kotlin's
    /// `maxByOrNull` the first. The two cannot disagree here: `index_cycle_periods_profile_id_
    /// start_date` is UNIQUE (`Migrations.swift:102`), so one profile has at most one period per
    /// start day and there are no ties to break.
    private static func snapshot(of periods: [CyclePeriodRecord], today: Int) -> CycleSnapshot {
        let latest = periods.max { $0.startDateEpochDay < $1.startDateEpochDay }
        let cycleDay = latest
            .flatMap { today >= $0.startDateEpochDay ? today - $0.startDateEpochDay + 1 : nil }
            .flatMap { $0 <= maxMeaningfulCycleDay ? $0 : nil }
        return CycleSnapshot(
            cycleDay: cycleDay,
            isPeriodOpen: latest != nil && latest?.endDateEpochDay == nil,
            averageCycleLengthDays: averageCycleLength(sortedStarts: periods.map(\.startDateEpochDay).sorted())
        )
    }

    /// `TodayRepositoryImpl.kt:94-98`. The mean is integer and **truncating**, matching Kotlin's
    /// `sum() / size` on `Int`; a run with no usable gap has no average at all rather than a zero
    /// the dashboard would draw as an empty progress bar.
    private static func averageCycleLength(sortedStarts: [Int]) -> Int? {
        let gaps = zip(sortedStarts, sortedStarts.dropFirst())
            .map { $1 - $0 }
            .filter { (minCycleLength ... maxCycleLength).contains($0) }
        guard gaps.isEmpty == false else { return nil }
        return gaps.reduce(0, +) / gaps.count
    }

    /// `TodayRepositoryImpl.kt:100-120`.
    private func vitalsStream(nowMs: Int64) -> AsyncThrowingStream<VitalsSnapshot, any Error> {
        mapped(
            latestOfFive(
                vitalsDao.observeRange(
                    profileId: profileId,
                    type: VitalType.weight.rawValue,
                    fromEpochMs: nowMs - Self.weightTrendWindowMs,
                    untilEpochMs: nowMs
                ),
                vitalsDao.observeLatest(profileId: profileId, type: VitalType.weight.rawValue),
                vitalsDao.observeLatest(profileId: profileId, type: VitalType.bloodPressure.rawValue),
                vitalsDao.observeLatest(profileId: profileId, type: VitalType.bloodGlucose.rawValue),
                throwingStream(over: preferences.userSettings)
            )
        ) { latest in
            VitalsSnapshot(
                latestWeightKg: latest.1?.valuePrimary,
                // Every reading in the window, in the DAO's oldest-first order, with no
                // downsampling: ten readings in one day would produce ten points, as on Android.
                weightTrend: latest.0.map { Float($0.valuePrimary) },
                latestSystolic: latest.2?.valuePrimary,
                latestDiastolic: latest.2?.valueSecondary,
                latestGlucoseMgdl: latest.3?.valuePrimary,
                glucoseUnit: latest.4.glucoseUnit
            )
        }
    }

    // MARK: - Constants (`TodayRepositoryImpl.kt:122-130`)

    private static let maxAppointments = 3
    /// Beyond this the "cycle day N" number stops being informative.
    private static let maxMeaningfulCycleDay = 60
    /// Gaps outside this range are treated as data noise, matching `CyclePredictor`'s bounds.
    private static let minCycleLength = 21
    private static let maxCycleLength = 45
    /// Kotlin's `30.days`, in the milliseconds the column stores.
    private static let weightTrendWindowMs: Int64 = 30 * 24 * 60 * 60 * 1000
}
