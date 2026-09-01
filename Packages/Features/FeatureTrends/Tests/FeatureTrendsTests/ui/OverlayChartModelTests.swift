// Ported from Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/ui/OverlayChartModelTest.kt`.

import SalusModel
import SalusUI
import Testing

@testable import FeatureTrends

/// The UI edge of the overlay analysis (`OverlayChartModelTest.kt`).
///
/// The rule these tests exist for: a line and its legend entry must describe the same series.
/// This chart shows no numbers, so the legend is the only thing attributing a colour to a metric
/// and a real range — a mismatch there would not look like a bug, it would look like data.
@Suite("OverlayChartModel")
struct OverlayChartModelTests {
    @Test("every series becomes one line, in the analysis's order")
    func everySeriesBecomesOneLine() {
        let model = overlayChartModelOf(
            overlay: overlay(
                series(.weight, 0, 1),
                series(.bloodPressure, 0.5, 0.25)
            ),
            xLabel: dayLabel
        )

        #expect(model?.chart.series.count == 2)
        #expect(model?.chart.series.map(\.role) == [.primary, .secondary])
    }

    @Test("normalized values are carried through untouched")
    func normalizedValuesAreCarriedThroughUntouched() {
        // The scaling happened in the analysis, where it is tested. Rescaling here would be a
        // second, invisible transform on values that are already on the axis they belong to.
        let model = overlayChartModelOf(
            overlay: overlay(
                series(.weight, 0, 0.75),
                series(.bloodGlucose, 1, 0.5)
            ),
            xLabel: dayLabel
        )

        let first = model?.chart.series.first
        #expect(first?.points.map(\.xEpochDay) == [firstDay, firstDay + 1])
        #expect(abs((first?.points.first?.y ?? 0) - 0) < tolerance)
        #expect(abs((first?.points.last?.y ?? 0) - 0.75) < tolerance)
    }

    @Test("each legend entry names its own line's metric, colour and real range")
    func eachLegendEntryNamesItsOwnLine() {
        let model = overlayChartModelOf(
            overlay: overlay(
                series(.bloodPressure, 0, 1, min: 118.0, max: 146.0),
                series(.weight, 1, 0, min: 68.4, max: 71.2)
            ),
            xLabel: dayLabel
        )

        let legend = model?.legend ?? []
        #expect(legend.map(\.role) == model?.chart.series.map(\.role))
        #expect(legend.map(\.type) == [.bloodPressure, .weight])
        #expect(legend.first?.min == 118.0)
        #expect(legend.first?.max == 146.0)
    }

    @Test("a single series is no overlay, so there is no card")
    func singleSeriesIsNoOverlay() {
        #expect(overlayChartModelOf(
            overlay: overlay(series(.weight, 0, 1)),
            xLabel: dayLabel
        ) == nil)
    }

    @Test("an empty overlay is no card either")
    func emptyOverlayIsNoCard() {
        #expect(overlayChartModelOf(overlay: MetricOverlay(series: []), xLabel: dayLabel) == nil)
    }

    @Test("a series with no points is not drawn, and not counted towards the pair")
    func seriesWithNoPointsIsNotDrawn() {
        // Unreachable from the analysis today, which is exactly why it is pinned here: a line
        // with nothing on it would still take a colour and claim a legend row.
        let model = overlayChartModelOf(
            overlay: overlay(
                series(.weight, 0, 1),
                OverlaySeries(type: .bloodGlucose, points: [], min: 0.0, max: 0.0)
            ),
            xLabel: dayLabel
        )

        #expect(model == nil)
    }

    @Test("the x labels the chart draws are the ones the caller supplied")
    func chartDrawsTheCallersLabels() {
        let model = overlayChartModelOf(
            overlay: overlay(
                series(.weight, 0, 1),
                series(.bloodPressure, 1, 0)
            ),
            xLabel: dayLabel
        )

        #expect(model?.chart.xLabel(firstDay) == dayLabel(firstDay))
    }

    // MARK: - Fixtures

    private func overlay(_ series: OverlaySeries...) -> MetricOverlay {
        MetricOverlay(series: series)
    }

    private func series(
        _ type: VitalType,
        _ values: Float...,
        min: Double = 1.0,
        max: Double = 2.0
    ) -> OverlaySeries {
        OverlaySeries(
            type: type,
            points: values.enumerated().map { index, value in
                OverlayPoint(xEpochDay: firstDay + index, y: value)
            },
            min: min,
            max: max
        )
    }

    private func dayLabel(_ epochDay: Int) -> String {
        "day \(epochDay)"
    }
}

private let firstDay = 20000
private let tolerance: Float = 0.0001
