// Ported from Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/analysis/TimeOfDayTest.kt`.

import SalusModel
import Testing

@testable import FeatureTrends

/// The time-of-day analysis (`TimeOfDayTest.kt`).
///
/// Every rule about which measurement lands in which bucket lives here: the function is pure, so
/// these tests are the whole specification of it — no clock, no database, no dispatcher.
@Suite("TimeOfDay")
struct TimeOfDayTests {
    @Test("all four parts come back, always, in declaration order")
    func allFourPartsComeBackInDeclarationOrder() {
        // A window with a single morning reading still describes the whole day: a part with no
        // measurement is a part the user did not measure in, which is itself worth showing.
        let breakdown = timeOfDayBreakdownOf(
            [measurement(minuteOfDay: morningMinute)],
            type: .bloodGlucose
        )

        #expect(breakdown.parts.map(\.part) == DayPart.allCases)
    }

    @Test("a part with no measurement counts zero and averages nothing")
    func partWithNoMeasurementCountsZero() {
        let breakdown = timeOfDayBreakdownOf(
            [measurement(minuteOfDay: morningMinute)],
            type: .bloodGlucose
        )

        let midday = breakdown.part(.midday)
        // swiftformat:disable isEmpty
        // swiftlint:disable:next empty_count
        #expect(midday.count == 0)
        // swiftformat:enable isEmpty
        #expect(midday.primaryAverage == nil)
        #expect(midday.secondaryAverage == nil)
    }

    @Test("the first minute of a bucket belongs to it and the one before it does not")
    func firstMinuteOfBucketBelongsToIt() {
        // 05:00 is the morning's opening minute; 04:59 is still the night before it.
        #expect(partOf(minuteOfDay: 300) == .morning)
        #expect(partOf(minuteOfDay: 299) == .night)
    }

    @Test("22 00 closes the evening rather than opening it")
    func twentyTwoHundredClosesTheEvening() {
        // The evening's boundary is exclusive: 1320 is the night's first minute, not the
        // evening's last.
        #expect(partOf(minuteOfDay: 1319) == .evening)
        #expect(partOf(minuteOfDay: 1320) == .night)
    }

    @Test("night collects both sides of midnight")
    func nightCollectsBothSidesOfMidnight() {
        // The only bucket that wraps. A 23:30 reading and a 01:30 reading are the same habit,
        // and splitting them across two buckets would hide it.
        let breakdown = timeOfDayBreakdownOf(
            [
                measurement(minuteOfDay: 23 * 60 + 30, primary: 100.0),
                measurement(minuteOfDay: 60 + 30, primary: 140.0)
            ],
            type: .bloodGlucose
        )

        let night = breakdown.part(.night)
        #expect(night.count == 2)
        #expect(abs((night.primaryAverage ?? 0) - 120.0) < tolerance)
    }

    @Test("blood pressure averages systolic as primary and diastolic as secondary")
    func bloodPressureAveragesSystolicAndDiastolic() {
        let breakdown = timeOfDayBreakdownOf(
            [
                measurement(
                    minuteOfDay: morningMinute,
                    type: .bloodPressure,
                    primary: 130.0,
                    secondary: 80.0
                ),
                measurement(
                    minuteOfDay: morningMinute,
                    type: .bloodPressure,
                    primary: 120.0,
                    secondary: 90.0
                )
            ],
            type: .bloodPressure
        )

        let morning = breakdown.part(.morning)
        #expect(breakdown.type == .bloodPressure)
        #expect(morning.count == 2)
        #expect(abs((morning.primaryAverage ?? 0) - 125.0) < tolerance)
        #expect(abs((morning.secondaryAverage ?? 0) - 85.0) < tolerance)
    }

    @Test("measurements of another type are not counted")
    func measurementsOfAnotherTypeAreNotCounted() {
        // The window carries every vital the user logs; asking for glucose must not average a
        // weight in kilograms into it.
        let breakdown = timeOfDayBreakdownOf(
            [
                measurement(minuteOfDay: morningMinute, type: .weight, primary: 70.0),
                measurement(minuteOfDay: morningMinute, type: .bloodGlucose, primary: 110.0)
            ],
            type: .bloodGlucose
        )

        let morning = breakdown.part(.morning)
        #expect(morning.count == 1)
        #expect(abs((morning.primaryAverage ?? 0) - 110.0) < tolerance)
    }

    @Test("one measurement averages to itself")
    func oneMeasurementAveragesToItself() {
        let breakdown = timeOfDayBreakdownOf(
            [measurement(minuteOfDay: morningMinute, primary: 97.0)],
            type: .bloodGlucose
        )

        #expect(abs((breakdown.part(.morning).primaryAverage ?? 0) - 97.0) < tolerance)
    }

    @Test("a type with no secondary value averages no secondary")
    func typeWithNoSecondaryAveragesNoSecondary() {
        let breakdown = timeOfDayBreakdownOf(
            [measurement(minuteOfDay: morningMinute)],
            type: .bloodGlucose
        )

        #expect(breakdown.part(.morning).secondaryAverage == nil)
    }

    @Test("blood pressure is preferred over glucose when both were logged")
    func bloodPressurePreferredOverGlucose() {
        // Both are shown on the same card, so one has to win. Blood pressure is the richer
        // reading, and the one whose time-of-day pattern people are told to watch.
        let breakdown = timeOfDayBreakdownOrNull(
            [
                measurement(minuteOfDay: morningMinute, type: .bloodGlucose),
                measurement(minuteOfDay: morningMinute, type: .bloodPressure, secondary: 80.0)
            ]
        )

        #expect(breakdown?.type == .bloodPressure)
    }

    @Test("glucose is used when there is no blood pressure")
    func glucoseUsedWhenNoBloodPressure() {
        let breakdown = timeOfDayBreakdownOrNull(
            [measurement(minuteOfDay: morningMinute, type: .bloodGlucose)]
        )

        #expect(breakdown?.type == .bloodGlucose)
    }

    @Test("neither metric logged means there is nothing to break down")
    func neitherMetricLoggedMeansNothingToBreakDown() {
        // Someone who only weighs themselves has no time-of-day story to tell, and the screen
        // uses the null to leave the card out rather than draw an empty chart.
        let breakdown = timeOfDayBreakdownOrNull(
            [measurement(minuteOfDay: morningMinute, type: .weight)]
        )

        #expect(breakdown == nil)
    }

    // MARK: - Fixtures

    private func partOf(minuteOfDay: Int) -> DayPart {
        let breakdown = timeOfDayBreakdownOf(
            [measurement(minuteOfDay: minuteOfDay)],
            type: .bloodGlucose
        )
        // swiftlint:disable:next force_unwrapping
        return breakdown.parts.first { $0.count == 1 }!.part
    }

    private func measurement(
        minuteOfDay: Int,
        type: VitalType = .bloodGlucose,
        primary: Double = 100.0,
        secondary: Double? = nil
    ) -> TrendMeasurement {
        TrendMeasurement(
            type: type,
            epochDay: epochDay,
            minuteOfDay: minuteOfDay,
            primary: primary,
            secondary: secondary,
            tertiary: nil
        )
    }
}

extension TimeOfDayBreakdown {
    fileprivate func part(_ part: DayPart) -> DayPartStats {
        // swiftlint:disable:next force_unwrapping
        parts.first { $0.part == part }!
    }
}

private let epochDay = 20000
private let morningMinute = 8 * 60
private let tolerance = 0.0001
