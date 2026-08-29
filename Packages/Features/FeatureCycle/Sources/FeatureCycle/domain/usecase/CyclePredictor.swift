// Ported 1:1 from Android
// `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/domain/usecase/CyclePredictor.kt`.
//
// Kotlin's `companion object` constants become `public static let` in camelCase; the names are
// Kotlin's word for word, so the doc comment above and the Android one describe the same numbers.
// `LocalDate.plus(n, DateTimeUnit.DAY)` / `.minus(…)` / `.daysUntil(…)` are `SalusModel`'s
// `plusDays(_:)` / `minusDays(_:)` / `daysUntil(_:)` — never raw `epochDay` arithmetic, so the
// proleptic-Gregorian rules stay in one place.

import SalusModel

/// Pure prediction algorithm — no clock access, `today` is always passed in
/// (`CyclePredictor.kt:37-111`).
///
/// Algorithm (see `docs/architecture/v1-plan.md`, "Cycle prediction"):
/// 1. Cycle lengths = day distance between consecutive recorded period starts (starts dated
///    after `today` are ignored as bad data); only the last ``maxTrackedCycles`` lengths are
///    considered.
/// 2. Lengths outside ``minCycleLengthDays``…``maxCycleLengthDays`` are filtered as outliers. If
///    everything is filtered out, the unfiltered lengths are used as a fallback (confidence
///    stays `.low`).
/// 3. Recency-weighted average (newest length weighs the most) of the remaining lengths gives
///    the predicted next start.
/// 4. Ovulation = next start − ``lutealPhaseDays``; fertile window =
///    ovulation − ``fertileWindowDaysBeforeOvulation`` … ovulation + ``fertileWindowDaysAfterOvulation``.
/// 5. Standard deviation > ``irregularSdDays`` or fewer than ``minUsableCycles`` usable cycles →
///    `.low` confidence + irregular flag; ``maxTrackedCycles`` usable cycles with
///    sd ≤ ``highConfidenceSdDays`` → `.high`; otherwise `.medium`.
///
/// An overdue prediction (next start before `today`) is returned as-is, never clamped forward.
/// Returns `nil` with fewer than ``minRecordedStarts`` recorded period starts. Predictions are
/// NEVER persisted.
public struct CyclePredictor: Sendable {
    public init() {}

    /// `CyclePredictor.kt:39-78`. Kotlin's `operator fun invoke` is `callAsFunction`, so the call
    /// site reads `predictor(periods, today: today)` on both platforms.
    public func callAsFunction(_ periods: [CyclePeriod], today: LocalDate) -> CyclePrediction? {
        // Kotlin's `distinct().sorted()`: the set drops the duplicates and the sort makes the
        // order the set lost irrelevant.
        let starts = Set(periods.map(\.startDate).filter { $0 <= today }).sorted()
        guard starts.count >= Self.minRecordedStarts, let lastStart = starts.last else {
            return nil
        }

        let lengths = Array(
            zip(starts, starts.dropFirst())
                .map { previous, next in previous.daysUntil(next) }
                .suffix(Self.maxTrackedCycles)
        )
        let usable = lengths.filter { (Self.minCycleLengthDays ... Self.maxCycleLengthDays).contains($0) }
        let considered = usable.isEmpty ? lengths : usable

        let standardDeviation = Self.standardDeviation(of: considered)
        let isIrregular = standardDeviation > Self.irregularSdDays || usable.count < Self.minUsableCycles
        let confidence: CycleConfidence = if isIrregular {
            .low
        } else if usable.count >= Self.maxTrackedCycles, standardDeviation <= Self.highConfidenceSdDays {
            .high
        } else {
            .medium
        }

        // Kotlin's `roundToInt` rounds half away from zero; the lengths are day counts, so the
        // value is always positive and `.toNearestOrAwayFromZero` is the same rule.
        let weightedAverage = Self.recencyWeightedAverage(of: considered)
        let averageCycleLength = Int(weightedAverage.rounded(.toNearestOrAwayFromZero))
        // Never clamped to the future: an overdue prediction stays in the past, which is what the
        // "N days late" copy reads.
        let nextPeriodStart = lastStart.plusDays(averageCycleLength)
        let ovulationDate = nextPeriodStart.minusDays(Self.lutealPhaseDays)

        return CyclePrediction(
            nextPeriodStart: nextPeriodStart,
            fertileWindowStart: ovulationDate.minusDays(Self.fertileWindowDaysBeforeOvulation),
            fertileWindowEnd: ovulationDate.plusDays(Self.fertileWindowDaysAfterOvulation),
            ovulationDate: ovulationDate,
            averageCycleLength: averageCycleLength,
            confidence: confidence,
            isIrregular: isIrregular
        )
    }

    /// Weighted mean where the oldest length weighs 1 and each newer length one more
    /// (`CyclePredictor.kt:81-90`).
    private static func recencyWeightedAverage(of lengths: [Int]) -> Double {
        var weightedSum = 0.0
        var weightTotal = 0.0
        for (index, length) in lengths.enumerated() {
            let weight = Double(index + 1)
            weightedSum += Double(length) * weight
            weightTotal += weight
        }
        return weightedSum / weightTotal
    }

    /// Population standard deviation of the (unweighted) lengths — divided by `n`, not `n - 1`
    /// (`CyclePredictor.kt:93-97`).
    private static func standardDeviation(of lengths: [Int]) -> Double {
        let count = Double(lengths.count)
        let mean = Double(lengths.reduce(0, +)) / count
        let variance = lengths.reduce(0.0) { total, length in
            let difference = Double(length) - mean
            return total + difference * difference
        } / count
        return variance.squareRoot()
    }

    // `CyclePredictor.kt:99-110`.
    public static let minRecordedStarts = 2
    public static let maxTrackedCycles = 6
    public static let minUsableCycles = 3
    public static let minCycleLengthDays = 21
    public static let maxCycleLengthDays = 45
    public static let irregularSdDays = 7.0
    public static let highConfidenceSdDays = 3.0
    public static let lutealPhaseDays = 14
    public static let fertileWindowDaysBeforeOvulation = 5
    public static let fertileWindowDaysAfterOvulation = 1
}
