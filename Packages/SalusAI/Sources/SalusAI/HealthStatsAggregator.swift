// Ported 1:1 from Android
// `core/ai/src/main/kotlin/com/alicansekban/salus/core/ai/HealthStatsAggregator.kt` (the
// `HealthStatsAggregator` class and the pure helper functions).

import Foundation
import os
import SalusCommon
import SalusDatabase
import SalusModel
import SalusSmoking

/// Reduces the stored health records of one period to the de-identified `HealthPeriodStats`
/// payload that is the only thing ever sent to the model, and — for the doctor report — to the
/// numeric `HealthPeriodRows` that stay on the device.
///
/// Free-form text — measurement notes, intake notes, medication names, the profile, the smoking
/// plan's reason — is never read: neither output type has a string field it could be carried in.
/// Smoking is the one table read through its repository rather than a DAO, and only to hand the
/// rows to `SmokingInsightsCalculator.aiStats`, whose result type is the contract's aggregate.
///
/// Both reads are deliberately thin. All arithmetic and all row mapping live in the pure
/// functions in this file so they can be tested without GRDB.
public struct HealthStatsAggregator: HealthPeriodReader {
    private let vitalsDao: VitalsDao
    private let medicationDao: MedicationDao
    private let profileId: String
    private let smokingRepository: any SmokingRepository

    public init(
        vitalsDao: VitalsDao,
        medicationDao: MedicationDao,
        profileId: String,
        smokingRepository: any SmokingRepository
    ) {
        self.vitalsDao = vitalsDao
        self.medicationDao = medicationDao
        self.profileId = profileId
        self.smokingRepository = smokingRepository
    }

    public func aggregate(
        period: SummaryPeriod,
        todayEpochDay: Int,
        timeZone: TimeZone
    ) async throws -> HealthPeriodStats {
        let days = periodBoundsOf(period, todayEpochDay: todayEpochDay)
        let millis = epochMsBoundsOf(days, timeZone: timeZone)
        return try await healthStatsOf(
            period: period,
            days: days,
            measurements: vitalsDao.getMeasurementsBetween(
                profileId: profileId,
                fromEpochMs: millis.lowerBound,
                untilEpochMs: millis.upperBound
            ),
            intakeLogs: medicationDao.getIntakeLogsBetween(
                profileId: profileId,
                fromEpochDay: days.lowerBound,
                toEpochDay: days.upperBound
            ),
            timeZone: timeZone,
            smoking: smokingStatsFor(days, timeZone: timeZone)
        )
    }

    /// The smoking aggregate for `days`, or `nil` when nothing is set up or the read failed.
    ///
    /// Total on purpose: smoking is an optional section of the prompt, and a failing smoking read
    /// must not take the vitals summary the user asked for down with it. The repository's stream
    /// does not throw - a storage failure ends it without an element - so "no element" is the
    /// failure signal here. The aggregate is cut on the same zone and day window as the vitals, so
    /// both halves of the prompt describe one period.
    private func smokingStatsFor(_ days: ClosedRange<Int>, timeZone: TimeZone) async -> SmokingAiStats? {
        var inputs = smokingRepository.observeInput().makeAsyncIterator()
        guard let input = await inputs.next() else {
            logger.warning("Smoking statistics left out of the summary: no input")
            return nil
        }
        return SmokingInsightsCalculator.aiStats(
            input,
            fromEpochDay: Int64(days.lowerBound),
            toEpochDay: Int64(days.upperBound),
            zone: timeZone
        )
    }

    public func periodRows(
        period: SummaryPeriod,
        todayEpochDay: Int,
        timeZone: TimeZone
    ) async throws -> HealthPeriodRows {
        let days = periodBoundsOf(period, todayEpochDay: todayEpochDay)
        let millis = epochMsBoundsOf(days, timeZone: timeZone)
        // Only the vitals table is read: the dose figures a report prints are counts, and those
        // already come out of `aggregate` as `loggedDoses`/`takenDoses`. Reading the intake rows
        // again would pull medication names and note text into memory for nothing.
        return try await healthRowsOf(
            days: days,
            measurements: vitalsDao.getMeasurementsBetween(
                profileId: profileId,
                fromEpochMs: millis.lowerBound,
                untilEpochMs: millis.upperBound
            ),
            timeZone: timeZone
        )
    }
}

/// Pure core of `HealthStatsAggregator.periodRows`: every measurement of the period, split by
/// type and mapped onto the note-free row types, oldest first.
///
/// Rows outside `days` are dropped for the same reason `healthStatsOf` drops them — a loose
/// query bound must not widen the period the report claims to cover.
func healthRowsOf(
    days: ClosedRange<Int>,
    measurements: [VitalsMeasurementRecord],
    timeZone: TimeZone
) -> HealthPeriodRows {
    let dated = measurements
        .map { row -> (VitalsMeasurementRecord, Int) in (row, row.epochDayIn(timeZone)) }
        .filter { days.contains($0.1) }
        .sorted { $0.0.measuredAtEpochMs < $1.0.measuredAtEpochMs }

    return HealthPeriodRows(
        bloodPressure: dated.ofType(.bloodPressure) { row, day in
            BloodPressureRow(
                epochDay: day,
                systolic: row.valuePrimary,
                diastolic: row.valueSecondary,
                pulse: row.valueTertiary
            )
        },
        glucose: dated.ofType(.bloodGlucose) { row, day in
            // Glucose is stored canonically in mg/dL, so the column needs no conversion.
            GlucoseRow(epochDay: day, mgDl: row.valuePrimary, context: row.contextOrNull())
        },
        weight: dated.ofType(.weight) { row, day in
            WeightRow(epochDay: day, kilograms: row.valuePrimary)
        }
    )
}

extension [(VitalsMeasurementRecord, Int)] {
    fileprivate func ofType<T>(_ type: VitalType, _ map: (VitalsMeasurementRecord, Int) -> T) -> [T] {
        filter { $0.0.type == type.rawValue }.map { map($0.0, $0.1) }
    }
}

extension VitalsMeasurementRecord {
    /// The stored context as an enum, or `nil` when the column is empty or holds a value this
    /// build does not know. An unknown string is dropped rather than printed: the report would
    /// otherwise put a raw database token in front of a doctor.
    fileprivate func contextOrNull() -> MeasurementContext? {
        guard let stored = measurementContext else { return nil }
        return MeasurementContext.allCases.first { $0.rawValue == stored }
    }
}

/// Inclusive day window a `SummaryPeriod` covers, ending on (and including) `todayEpochDay`.
func periodBoundsOf(_ period: SummaryPeriod, todayEpochDay: Int) -> ClosedRange<Int> {
    let dayCount = switch period {
    case .weekly: weeklyDayCount
    case .monthly: monthlyDayCount
    }
    return (todayEpochDay - dayCount + 1) ... todayEpochDay
}

/// Inclusive epoch-millisecond window matching `days` in `timeZone`, for the vitals query —
/// measurements are stored as absolute instants, the period is expressed in local days.
func epochMsBoundsOf(_ days: ClosedRange<Int>, timeZone: TimeZone) -> ClosedRange<Int64> {
    let from = LocalDateTime(date: LocalDate(epochDay: days.lowerBound), minuteOfDay: 0)
        .instant(in: timeZone)
        .epochMilliseconds
    let untilExclusive = LocalDateTime(date: LocalDate(epochDay: days.upperBound + 1), minuteOfDay: 0)
        .instant(in: timeZone)
        .epochMilliseconds
    return from ... (untilExclusive - 1)
}

/// Pure core of `HealthStatsAggregator.aggregate`: everything the snapshot reports, derived from
/// the two record lists. Rows outside `days` are dropped, so a loose query bound cannot widen the
/// reported period.
func healthStatsOf(
    period: SummaryPeriod,
    days: ClosedRange<Int>,
    measurements: [VitalsMeasurementRecord],
    intakeLogs: [MedicationIntakeLogRecord],
    timeZone: TimeZone,
    smoking: SmokingAiStats? = nil
) -> HealthPeriodStats {
    let dated = measurements
        .map { row -> (VitalsMeasurementRecord, Int) in (row, row.epochDayIn(timeZone)) }
        .filter { days.contains($0.1) }
        .sorted { $0.0.measuredAtEpochMs < $1.0.measuredAtEpochMs }
    let inPeriod = dated.map(\.0)
    let dosesInPeriod = intakeLogs.filter { days.contains($0.scheduledDateEpochDay) }
    let bloodPressure = inPeriod.filter { $0.type == VitalType.bloodPressure.rawValue }

    var recordDays = Set<Int>()
    for (_, day) in dated {
        recordDays.insert(day)
    }
    for log in dosesInPeriod {
        recordDays.insert(log.scheduledDateEpochDay)
    }

    return HealthPeriodStats(
        periodType: period,
        startEpochDay: days.lowerBound,
        endEpochDay: days.upperBound,
        distinctRecordDays: recordDays.count,
        systolic: metricStatsOf(bloodPressure.map(\.valuePrimary)),
        diastolic: metricStatsOf(bloodPressure.compactMap(\.valueSecondary)),
        pulse: metricStatsOf(bloodPressure.compactMap(\.valueTertiary)),
        // Glucose is stored canonically in mg/dL, so it needs no conversion here.
        glucoseMgDl: metricStatsOf(inPeriod.primaryValuesOf(.bloodGlucose)),
        weightKg: metricStatsOf(inPeriod.primaryValuesOf(.weight)),
        // Both counts come out of the same list, so taken can never exceed logged and
        // takenPercent can never render above 100%.
        loggedDoses: dosesInPeriod.count,
        takenDoses: dosesInPeriod.count { $0.status == IntakeStatus.taken.rawValue },
        smoking: smoking
    )
}

extension [VitalsMeasurementRecord] {
    fileprivate func primaryValuesOf(_ type: VitalType) -> [Double] {
        filter { $0.type == type.rawValue }.map(\.valuePrimary)
    }
}

extension VitalsMeasurementRecord {
    /// The local day this reading falls on in `timeZone` — the twin of
    /// `Instant.fromEpochMilliseconds(measuredAtEpochMs).toLocalDateTime(timeZone).date.epochDay`.
    fileprivate func epochDayIn(_ timeZone: TimeZone) -> Int {
        Date(epochMilliseconds: measuredAtEpochMs).wallClock(in: timeZone).date.epochDay
    }
}

/// Shared with the rest of the app's log output, so one filter catches everything.
private let logger = Logger(subsystem: "com.alicansekban.salus", category: "ai")

private let weeklyDayCount = 7
private let monthlyDayCount = 30
