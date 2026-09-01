// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/DoseWeeksChartModel.kt`.

import SalusUI

/// One drawn week: the bar's caption and share, plus the averages written under it
/// (`DoseWeeksChartModel.kt:19-24`).
///
/// `label` is the same string the bar carries, taken from the same call, so the line of text
/// describing a week and the column standing for it cannot come to name two different weeks.
///
/// The averages stay as numbers in canonical units. Converting them here would put a display
/// setting inside the chart mapping; the card writes them out through `MetricDisplay`, which is
/// the one place a stored value becomes a value the reader sees.
struct DoseWeekBar {
    let label: String
    let takenPercent: Int
    let systolicAverage: Double?
    let glucoseAverage: Double?
}

/// The chart and the lines that caption it, produced together (`DoseWeeksChartModel.kt:27-30`).
struct DoseWeeksChartModel {
    let chart: BarChartUiModel
    let weeks: [DoseWeekBar]
}

/// Turns weekly dose records into chart input (`DoseWeeksChartModel.kt:60-83`).
///
/// The whole UI edge of the weekly dose analysis, and a plain function rather than a block inside
/// the view so that its rules are covered by unit tests instead of by looking at a device — the
/// same shape `barChartModelOf` and `overlayChartModelOf` have.
///
/// Three rules:
///
/// 1. A week with no logged dose produces no bar. It has no share to draw, and a zero-height
///    column would read as a week whose doses all went untaken — a claim about the user's
///    medication that the records do not support.
/// 2. No bar ever carries a secondary value. The second series of a bar chart shares the first
///    one's axis, and this axis is a percentage; millimetres of mercury and milligrams per
///    decilitre have no place on it. The week's averages travel in `DoseWeeksChartModel.weeks`
///    and are written out beside the chart instead.
/// 3. The bars and the captions come from one pass over the same weeks, in the same order, so
///    the two lists are the same length by construction.
///
/// - Parameters:
///   - weekLabel: the localized caption for the week starting on an epoch day. Passed in rather
///     than resolved here, because dates are the view's business and this function has to stay
///     testable.
///   - axisLabel: writes an axis tick. The values are whole percentages, so no conversion is
///     involved — unlike the metric charts, this one has no unit the reader can change.
/// - Returns: `nil` when no week holds a logged dose, meaning there is no card to draw. The
///   analysis already answers `nil` for the same reason; this is the same answer at the other
///   end, so "nothing to show" stays a `nil` model throughout.
func doseWeeksChartModelOf(
    weeks: [DoseWeek],
    weekLabel: (Int) -> String,
    axisLabel: @escaping @Sendable (Float) -> String
) -> DoseWeeksChartModel? {
    let drawn = weeks.compactMap { week -> DoseWeekBar? in
        week.takenPercent.map { percent in
            DoseWeekBar(
                label: weekLabel(week.startEpochDay),
                takenPercent: percent,
                systolicAverage: week.systolicAverage,
                glucoseAverage: week.glucoseAverage
            )
        }
    }
    if drawn.isEmpty {
        return nil
    }

    let bars = drawn.map { week in
        BarEntry(label: week.label, value: Float(week.takenPercent))
    }

    return DoseWeeksChartModel(
        chart: BarChartUiModel(bars: bars, yLabel: axisLabel),
        weeks: drawn
    )
}
