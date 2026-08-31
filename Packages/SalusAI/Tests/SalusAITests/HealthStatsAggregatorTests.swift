import Foundation
import SalusDatabase
import SalusModel
import Testing

@testable import SalusAI

// Ported 1:1 from Android
// `core/ai/src/test/kotlin/com/alicansekban/salus/core/ai/HealthStatsAggregatorTest.kt`.

/// Covers the pure aggregation helpers. `aggregate` itself is thin orchestration over two DAO
/// calls, so it needs neither GRDB nor a database here.
@Suite("HealthStatsAggregator (Android parity)")
struct HealthStatsAggregatorTests {
    // --- periodBoundsOf ---

    @Test("weekly period covers today and the previous six days")
    func weeklyPeriodCoversTodayAndThePreviousSixDays() {
        let days = periodBoundsOf(.weekly, todayEpochDay: today)

        #expect(days.lowerBound == today - 6)
        #expect(days.upperBound == today)
        #expect(days.count == 7)
    }

    @Test("monthly period covers today and the previous twenty nine days")
    func monthlyPeriodCoversTodayAndThePreviousTwentyNineDays() {
        let days = periodBoundsOf(.monthly, todayEpochDay: today)

        #expect(days.lowerBound == today - 29)
        #expect(days.upperBound == today)
        #expect(days.count == 30)
    }

    // --- epochMsBoundsOf ---

    @Test("epoch millisecond bounds span whole local days in utc")
    func epochMillisecondBoundsSpanWholeLocalDaysInUtc() {
        let bounds = epochMsBoundsOf(20000 ... 20006, timeZone: utc)

        #expect(bounds.lowerBound == 20000 * msPerDay)
        #expect(bounds.upperBound == 20007 * msPerDay - 1)
    }

    @Test("epoch millisecond bounds shift with the requested zone")
    func epochMillisecondBoundsShiftWithTheRequestedZone() {
        let bounds = epochMsBoundsOf(20000 ... 20006, timeZone: istanbul)

        #expect(bounds.lowerBound == 20000 * msPerDay - istanbulOffsetMs)
        #expect(bounds.upperBound == 20007 * msPerDay - istanbulOffsetMs - 1)
    }

    // --- healthStatsOf: vitals ---

    @Test("blood pressure rows fill the systolic diastolic and pulse slots")
    func bloodPressureRowsFillTheSystolicDiastolicAndPulseSlots() {
        let stats = healthStatsOf(
            period: .weekly,
            days: week,
            measurements: [
                measurement(.bloodPressure, utcMs(today - 2), 120.0, 80.0, tertiary: 60.0),
                measurement(.bloodPressure, utcMs(today - 1), 130.0, 84.0, tertiary: 70.0)
            ],
            intakeLogs: [],
            timeZone: utc
        )

        #expect(stats.systolic?.average == 125.0)
        #expect(stats.diastolic?.average == 82.0)
        #expect(stats.pulse?.average == 65.0)
    }

    @Test("a blood pressure row without a pulse leaves the pulse slot empty")
    func aBloodPressureRowWithoutAPulseLeavesThePulseSlotEmpty() {
        let stats = healthStatsOf(
            period: .weekly,
            days: week,
            measurements: [
                measurement(.bloodPressure, utcMs(today), 118.0, 76.0, tertiary: nil)
            ],
            intakeLogs: [],
            timeZone: utc
        )

        #expect(stats.systolic?.count == 1)
        #expect(stats.diastolic?.count == 1)
        #expect(stats.pulse == nil)
    }

    @Test("glucose and weight read their primary value and unmeasured metrics stay null")
    func glucoseAndWeightReadTheirPrimaryValueAndUnmeasuredMetricsStayNull() {
        let stats = healthStatsOf(
            period: .weekly,
            days: week,
            measurements: [
                measurement(.bloodGlucose, utcMs(today - 1), 110.0),
                measurement(.weight, utcMs(today), 81.5)
            ],
            intakeLogs: [],
            timeZone: utc
        )

        #expect(stats.glucoseMgDl?.average == 110.0)
        #expect(stats.weightKg?.average == 81.5)
        #expect(stats.systolic == nil)
        #expect(stats.diastolic == nil)
        #expect(stats.pulse == nil)
    }

    @Test("trend follows chronological order regardless of the input order")
    func trendFollowsChronologicalOrderRegardlessOfTheInputOrder() {
        let rising = (0 ... 5).map { measurement(.weight, utcMs(today - 5 + $0), 80.0 + Double($0) * 2) }

        let stats = healthStatsOf(
            period: .weekly,
            days: week,
            measurements: rising.reversed(),
            intakeLogs: [],
            timeZone: utc
        )

        #expect(stats.weightKg?.trend == .rising)
    }

    @Test("records outside the period are ignored")
    func recordsOutsideThePeriodAreIgnored() {
        let stats = healthStatsOf(
            period: .weekly,
            days: week,
            measurements: [measurement(.weight, utcMs(today - 10), 90.0)],
            intakeLogs: [log(today - 10, .taken)],
            timeZone: utc
        )

        #expect(stats.weightKg == nil)
        #expect(stats.distinctRecordDays == 0)
        #expect(stats.loggedDoses == 0)
    }

    @Test("the period bounds are carried into the snapshot")
    func thePeriodBoundsAreCarriedIntoTheSnapshot() {
        let stats = healthStatsOf(
            period: .monthly,
            days: (today - 29) ... today,
            measurements: [],
            intakeLogs: [],
            timeZone: utc
        )

        #expect(stats.periodType == .monthly)
        #expect(stats.startEpochDay == today - 29)
        #expect(stats.endEpochDay == today)
    }

    // --- healthStatsOf: distinctRecordDays ---

    @Test("two records on the same day count as one record day")
    func twoRecordsOnTheSameDayCountAsOneRecordDay() {
        let stats = healthStatsOf(
            period: .weekly,
            days: week,
            measurements: [
                measurement(.weight, utcMs(today, hour: 7), 80.0),
                measurement(.bloodGlucose, utcMs(today, hour: 21), 105.0)
            ],
            intakeLogs: [log(today, .taken)],
            timeZone: utc
        )

        #expect(stats.distinctRecordDays == 1)
    }

    @Test("a day with only an intake log still counts as a record day")
    func aDayWithOnlyAnIntakeLogStillCountsAsARecordDay() {
        let stats = healthStatsOf(
            period: .weekly,
            days: week,
            measurements: [measurement(.weight, utcMs(today), 80.0)],
            intakeLogs: [log(today - 3, .skipped)],
            timeZone: utc
        )

        #expect(stats.distinctRecordDays == 2)
    }

    @Test("a measurement is bucketed by the requested zone not by utc")
    func aMeasurementIsBucketedByTheRequestedZoneNotByUtc() {
        // 22:30 UTC on the day before "today" is already 01:30 of "today" in Istanbul.
        let lateEvening = utcMs(today - 1, hour: 22) + 30 * msPerMinute
        let rows = [
            measurement(.weight, lateEvening, 80.0),
            measurement(.weight, utcMs(today, hour: 9), 80.5)
        ]

        func statsIn(_ zone: TimeZone) -> HealthPeriodStats {
            healthStatsOf(
                period: .weekly,
                days: week,
                measurements: rows,
                intakeLogs: [],
                timeZone: zone
            )
        }

        #expect(statsIn(utc).distinctRecordDays == 2)
        #expect(statsIn(istanbul).distinctRecordDays == 1)
    }

    // --- healthStatsOf: dose ratio ---

    @Test("taken percent is null when no dose was logged in the period")
    func takenPercentIsNullWhenNoDoseWasLoggedInThePeriod() {
        let stats = healthStatsOf(
            period: .weekly,
            days: week,
            measurements: [],
            intakeLogs: [],
            timeZone: utc
        )

        #expect(stats.loggedDoses == 0)
        #expect(stats.takenDoses == 0)
        #expect(stats.takenPercent == nil)
    }

    @Test("only TAKEN rows count as taken while every recorded row counts as logged")
    func onlyTakenRowsCountAsTakenWhileEveryRecordedRowCountsAsLogged() {
        let stats = healthStatsOf(
            period: .weekly,
            days: week,
            measurements: [],
            intakeLogs: [
                log(today, .taken, minutes: 8 * 60),
                log(today, .skipped, minutes: 14 * 60),
                log(today - 1, .missed, minutes: 8 * 60),
                log(today - 2, .pending, minutes: 8 * 60)
            ],
            timeZone: utc
        )

        #expect(stats.loggedDoses == 4)
        #expect(stats.takenDoses == 1)
        #expect(stats.takenPercent == 25)
    }

    @Test("taken doses can never exceed logged doses so the ratio stays at or below one hundred")
    func takenDosesCanNeverExceedLoggedDosesSoTheRatioStaysAtOrBelowOneHundred() {
        let allTaken = (0 ... 6).map { log(today - $0, .taken) }

        let stats = healthStatsOf(
            period: .weekly,
            days: week,
            measurements: [],
            intakeLogs: allTaken,
            timeZone: utc
        )

        #expect(stats.takenDoses <= stats.loggedDoses)
        #expect(stats.takenPercent == 100)
    }

    // --- healthRowsOf ---

    @Test("rows map to their note-free types oldest first")
    func rowsMapToTheirNoteFreeTypesOldestFirst() {
        let rows = healthRowsOf(
            days: week,
            measurements: [
                measurement(.weight, utcMs(today - 1), 81.5),
                measurement(.bloodPressure, utcMs(today - 2), 120.0, 80.0, tertiary: 60.0),
                measurement(.bloodGlucose, utcMs(today - 3), 110.0)
            ],
            timeZone: utc
        )

        #expect(rows.bloodPressure == [BloodPressureRow(
            epochDay: today - 2,
            systolic: 120.0,
            diastolic: 80.0,
            pulse: 60.0
        )])
        #expect(rows.glucose == [GlucoseRow(epochDay: today - 3, mgDl: 110.0, context: nil)])
        #expect(rows.weight == [WeightRow(epochDay: today - 1, kilograms: 81.5)])
        #expect(!rows.isEmpty)
    }

    @Test("rows outside the period are dropped and empty rows report empty")
    func rowsOutsideThePeriodAreDroppedAndEmptyRowsReportEmpty() {
        let rows = healthRowsOf(
            days: week,
            measurements: [measurement(.weight, utcMs(today - 10), 90.0)],
            timeZone: utc
        )

        #expect(rows.bloodPressure.isEmpty)
        #expect(rows.glucose.isEmpty)
        #expect(rows.weight.isEmpty)
        #expect(rows.isEmpty)
    }

    // --- helpers ---

    private let today = 20100
    private let week = (20100 - 6) ... 20100
    // A missing tz database entry must fail loudly rather than fall back to some other zone, which
    // is what these two bangs are for.
    // swiftlint:disable force_unwrapping
    private let utc = TimeZone(secondsFromGMT: 0)!
    private let istanbul = TimeZone(identifier: "Europe/Istanbul")!
    // swiftlint:enable force_unwrapping
    private let msPerDay: Int64 = 86_400_000
    private let msPerMinute: Int64 = 60000
    private let istanbulOffsetMs: Int64 = 3 * 60 * 60 * 1000
}

private func utcMs(_ epochDay: Int, hour: Int = 12) -> Int64 {
    Int64(epochDay) * 86_400_000 + Int64(hour) * 3_600_000
}

private func measurement(
    _ type: VitalType,
    _ epochMs: Int64,
    _ primary: Double,
    _ secondary: Double? = nil,
    tertiary: Double? = nil
) -> VitalsMeasurementRecord {
    VitalsMeasurementRecord(
        id: "measurement-\(epochMs)-\(type.rawValue)",
        profileId: "profile-1",
        type: type.rawValue,
        measuredAtEpochMs: epochMs,
        timeZoneId: "Europe/Istanbul",
        valuePrimary: primary,
        valueSecondary: secondary,
        valueTertiary: tertiary,
        unit: "unit",
        measurementContext: nil,
        note: "free-form note that must never reach the model"
    )
}

private func log(_ epochDay: Int, _ status: IntakeStatus, minutes: Int = 8 * 60) -> MedicationIntakeLogRecord {
    MedicationIntakeLogRecord(
        id: "log-\(epochDay)-\(minutes)-\(status.rawValue)",
        scheduleId: "schedule-1",
        medicationId: "medication-1",
        profileId: "profile-1",
        scheduledDateEpochDay: epochDay,
        scheduledMinutes: minutes,
        status: status.rawValue,
        takenAtEpochMs: nil,
        snoozedUntilEpochMs: nil,
        doseAmount: 1.0,
        note: "free-form note that must never reach the model"
    )
}
