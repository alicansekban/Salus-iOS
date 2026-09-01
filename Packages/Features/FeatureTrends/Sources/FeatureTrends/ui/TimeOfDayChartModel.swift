// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/TimeOfDayChartModel.kt`.

import SalusModel
import SalusUI

/// Turns a `TimeOfDayBreakdown` into chart input (`TimeOfDayChartModel.kt:41-69`).
///
/// This is the whole UI edge of the time-of-day analysis, and it is a plain function rather than
/// a block inside the view so that its rules are covered by unit tests instead of by looking at
/// a device.
///
/// Two rules, and both exist to keep the two series sharing one x axis by construction:
///
/// 1. A bucket with no measurement produces no bar. There is no zero-height placeholder — a
///    reading of zero is not a thing a person has, and inventing one to hold an axis slot would
///    be a fabricated value on a health screen.
/// 2. The secondary series is emitted only when *every* emitted bar carries a secondary value.
///    A blood pressure row that somehow lost its diastolic would otherwise leave the second
///    series covering fewer x values than the first, and how a grouped column layer renders
///    that mismatch is not something this code should be relying on. Systolic alone is still
///    an honest chart; a half-populated pair is not.
///
/// - Parameters:
///   - partLabel: the localized caption for a bucket. Passed in rather than resolved here,
///     because resources are the view's business and this function has to stay testable.
///   - displayValue: converts a stored average into the unit the reader chose. Glucose is
///     stored and averaged in canonical mg/dL, so the conversion has to happen here rather than
///     further in — both the bars and the axis they are measured against must be in one unit,
///     and this is the single point they both come from.
///   - axisLabel: writes an axis tick, in whatever unit `displayValue` produced.
/// - Returns: `nil` when no bucket holds a measurement, meaning there is no card to draw.
func barChartModelOf(
    breakdown: TimeOfDayBreakdown,
    partLabel: (DayPart) -> String,
    displayValue: (Double) -> Double,
    axisLabel: @escaping @Sendable (Float) -> String
) -> BarChartUiModel? {
    let measured = breakdown.parts.compactMap { stats -> MeasuredPart? in
        // swiftformat:disable isEmpty
        // swiftlint:disable:next empty_count
        guard let primary = stats.primaryAverage, stats.count > 0 else { return nil }
        // swiftformat:enable isEmpty
        return MeasuredPart(part: stats.part, primary: primary, secondary: stats.secondaryAverage)
    }
    if measured.isEmpty {
        return nil
    }

    let hasPairedSeries = measured.allSatisfy { $0.secondary != nil }
    let bars = measured.map { part in
        BarEntry(
            label: partLabel(part.part),
            value: Float(displayValue(part.primary)),
            secondaryValue: part.secondary
                .flatMap { hasPairedSeries ? $0 : nil }
                .map { Float(displayValue($0)) }
        )
    }

    return BarChartUiModel(bars: bars, yLabel: axisLabel)
}

/// A bucket that actually holds a measurement, with its averages already unwrapped
/// (`TimeOfDayChartModel.kt:72-76`).
private struct MeasuredPart {
    let part: DayPart
    let primary: Double
    let secondary: Double?
}
