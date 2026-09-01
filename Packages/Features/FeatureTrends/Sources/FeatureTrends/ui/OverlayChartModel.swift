// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/OverlayChartModel.kt`.

import SalusModel
import SalusUI

/// One legend line's worth of facts, still as numbers (`OverlayChartModel.kt:20-25`).
///
/// The card turns this into text — a localized metric name, a unit, digits in the reader's
/// locale — but the *pairing* of a metric with the colour its line is drawn in is decided here,
/// next to the chart series it came from, so the two cannot fall out of step.
struct OverlayLegendItem {
    let type: VitalType
    let role: SeriesRole
    let min: Double
    let max: Double
}

/// The chart and the key that makes it readable, produced together (`OverlayChartModel.kt:28-31`).
struct OverlayChartModel {
    let chart: MultiSeriesChartUiModel
    let legend: [OverlayLegendItem]
}

/// Turns a `MetricOverlay` into chart input (`OverlayChartModel.kt:51-89`).
///
/// The whole UI edge of the overlay analysis, and a plain function rather than a block inside
/// the composable so that its rules are covered by unit tests instead of by looking at a device —
/// the same shape `barChartModelOf` has.
///
/// The chart and the legend come back together on purpose. This normalized chart shows no
/// numbers at all, so the legend is the only place a line can be attributed to a metric and a
/// real value; building the two from separate passes over the analysis would let a card promise
/// a colour the chart does not draw.
///
/// - Parameters:
///   - xLabel: the caption for an epoch day, already localized. Passed in rather than resolved
///     here, because resources are the view's business and this has to stay testable.
/// - Returns: `nil` when fewer than `minOverlaySeries` series are left to draw, meaning there is
///   no card. The analysis already answers `nil` for the same reason; this is the same answer at
///   the other end, so "nothing to show" stays a `nil` model throughout.
func overlayChartModelOf(
    overlay: MetricOverlay,
    xLabel: @escaping @Sendable (Int) -> String
) -> OverlayChartModel? {
    // A series with no points cannot be drawn and could not be honestly captioned either. The
    // analysis makes it unreachable today; it is answered here rather than assumed away.
    // Roles run out before metrics never would, but taking only as many as exist keeps the
    // role lookup below total instead of relying on the two enums staying the same size.
    let drawable = Array(overlay.series
        .filter { !$0.points.isEmpty }
        .prefix(SeriesRole.allCases.count))
    if drawable.count < minOverlaySeries {
        return nil
    }

    let roles = SeriesRole.allCases
    let chartSeries = drawable.enumerated().map { index, series in
        ChartSeries(
            points: series.points.map { point in
                ChartPoint(xEpochDay: point.xEpochDay, y: point.y)
            },
            role: roles[index]
        )
    }
    let legend = drawable.enumerated().map { index, series in
        OverlayLegendItem(
            type: series.type,
            role: roles[index],
            min: series.min,
            max: series.max
        )
    }

    return OverlayChartModel(
        chart: MultiSeriesChartUiModel(
            series: chartSeries,
            xLabel: xLabel
        ),
        legend: legend
    )
}
