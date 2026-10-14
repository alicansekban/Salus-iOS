// Ported from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/SmokingTrendsModel.kt`
// (`reductionChartModelOf`).

import SalusUI

/// The reduction curve: units per day, one point per week since setup.
///
/// x is the 1-based week number, so the axis caption is the caller's "n. hafta" and no date maths is
/// involved. A week with no logged day has no point — a gap in the line, never a zero, because a week
/// nobody recorded is not a week of not smoking.
///
/// - Returns: `nil` unless at least two weeks have a value: one point is a number, not a curve.
func reductionChartModelOf(
    weekly: [Int64?],
    weekLabel: @escaping @Sendable (Int) -> String
) -> ChartUiModel? {
    let points = weekly.enumerated().compactMap { index, units in
        units.map { ChartPoint(xEpochDay: index + 1, y: Float($0)) }
    }
    guard points.count >= minCurvePoints else { return nil }
    return ChartUiModel(
        points: points,
        xLabel: weekLabel,
        yLabel: { String(Int($0.rounded())) }
    )
}

/// One point is a number, not a curve.
private let minCurvePoints = 2
