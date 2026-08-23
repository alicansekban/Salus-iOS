// Ported from `core/ui/.../chart/SalusLineChart.kt:31-125`.
//
// This file is the reason `SalusUI` exists as a layer and the reason features are forbidden to
// `import Charts` (CLAUDE.md, enforced by the `.swiftlint.yml` rule `no_charts_in_features`): the
// chart engine is an implementation detail, and it is a different engine on each platform — Vico
// there, Swift Charts here. `ChartUiModel` is the contract both sides speak.
//
// Vico concepts and what replaces them:
//
//   * `CartesianChartModelProducer` + `runTransaction` (`SalusLineChart.kt:39-58`) push points into
//     the chart asynchronously. Swift Charts is declarative — the marks ARE the data — so the
//     producer, the `LaunchedEffect` and the "skip the transaction when empty" guard all collapse
//     into `ForEach` over the model.
//   * `ProvideVicoTheme(rememberM3VicoTheme())` (`:80`) hands Vico the Material scheme. Swift Charts
//     draws with what each mark is given, so the colors are named per mark from the resolved theme.
//   * `CartesianValueFormatter` (`:61-78`) becomes `AxisValueLabel`, calling the same two closures.
//   * `rememberVicoZoomState(initialZoom = Zoom.Content)` (`:115`) makes Vico open showing the whole
//     selected period instead of its own 1:1 default. Swift Charts already plots the full domain in
//     the available width; the twin of "open on Content" is therefore to add no scroll modifier.
//     Vico's residual scroll/zoom gestures have no Swift Charts equivalent that keeps the whole
//     period visible, and a period the user picked from the range control is the thing to show.

import Charts
import SalusDesignSystem
import SwiftUI

/// The one line chart in the app. Feature screens pass a `ChartUiModel` and never see the engine.
public struct SalusLineChart: View {
    private let model: ChartUiModel
    private let lineColor: Color?
    private let contentDescription: String?

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - lineColor: the primary series' color. `nil` means the primary role, the twin of Kotlin's
    ///     `MaterialTheme.colorScheme.primary` default (`SalusLineChart.kt:35`) — which cannot be a
    ///     Swift default argument because it is read from the environment.
    ///   - contentDescription: spoken summary of the chart (e.g. the latest value); charts are
    ///     opaque to VoiceOver exactly as they are to TalkBack (`SalusLineChart.kt:36`).
    public init(
        model: ChartUiModel,
        lineColor: Color? = nil,
        contentDescription: String? = nil
    ) {
        self.model = model
        self.lineColor = lineColor
        self.contentDescription = contentDescription
    }

    public var body: some View {
        chart
            // Vico's `CartesianLayerRangeProvider.auto()`, ported (see `ChartAxisScale`). Without
            // these two, Swift Charts rounds a numeric axis out to whole hundreds of epoch days and
            // a ten-day series draws as a near-vertical sliver.
            .chartXScaleIfSet(ChartAxisScale.xDomain(for: model))
            .chartYScaleIfSet(ChartAxisScale.yDomain(for: model))
            .chartXAxis { xAxis }
            .chartYAxis { yAxis }
            // Vico draws no legend unless one is added (`SalusLineChart.kt:81-107` adds none), and
            // Swift Charts synthesises one from the series ids, so it is turned off here.
            .chartLegend(.hidden)
            .accessibilitySummary(contentDescription)
    }

    private var primaryColor: Color { lineColor ?? theme.colorScheme.primary }

    /// `MaterialTheme.colorScheme.tertiary` (`SalusLineChart.kt:60`).
    private var secondaryColor: Color { theme.colorScheme.tertiary }

    private var chart: some View {
        Chart {
            ForEach(model.points, id: \.xEpochDay) { point in
                // Gradient area under the line, fading to transparent; in dark themes the brighter
                // accent gives the mockups' glow feel for free (`SalusLineChart.kt:87-98`).
                AreaMark(
                    x: .value(Self.xSeriesId, point.xEpochDay),
                    y: .value(Self.ySeriesId, point.y)
                )
                .foregroundStyle(areaGradient)

                LineMark(
                    x: .value(Self.xSeriesId, point.xEpochDay),
                    y: .value(Self.ySeriesId, point.y),
                    series: .value(Self.seriesId, Self.primarySeries)
                )
                .foregroundStyle(primaryColor)
            }

            ForEach(model.secondaryPoints, id: \.xEpochDay) { point in
                LineMark(
                    x: .value(Self.xSeriesId, point.xEpochDay),
                    y: .value(Self.ySeriesId, point.y),
                    series: .value(Self.seriesId, Self.secondarySeries)
                )
                .foregroundStyle(secondaryColor)
            }
        }
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor.opacity(Self.areaTopAlpha), primaryColor.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// `HorizontalAxis.rememberBottom(valueFormatter = bottomFormatter)` (`SalusLineChart.kt:106`),
    /// with the mark positions coming from the data rather than from Swift Charts' round numbers —
    /// see `ChartAxisScale.xAxisValues(for:)` for how that lines up with Vico's item placer.
    private var xAxis: some AxisContent {
        AxisMarks(values: ChartAxisScale.xAxisValues(for: model)) { value in
            AxisGridLine()
            AxisTick()
            // The first and last marks sit exactly on the plot edges, because the domain is the
            // data's own range. A centred label there would hang half outside the chart, and Swift
            // Charts drops rather than clips it — the last date simply vanished. Anchoring the
            // extremes inwards is Vico's `shiftExtremeLines` idea applied to the labels.
            AxisValueLabel(anchor: Self.labelAnchor(at: value.index, of: value.count)) {
                if let epochDay = value.as(Int.self) {
                    Text(model.xLabel(epochDay))
                }
            }
        }
    }

    private static func labelAnchor(at index: Int, of count: Int) -> UnitPoint {
        switch index {
        case 0: .topLeading
        case count - 1: .topTrailing
        default: .top
        }
    }

    /// `VerticalAxis.rememberStart(valueFormatter = startFormatter)` (`SalusLineChart.kt:105`) —
    /// "start" is the leading edge, which is `.leading` here.
    private var yAxis: some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisGridLine()
            AxisTick()
            AxisValueLabel {
                if let y = value.as(Double.self) {
                    Text(model.yLabel(Float(y)))
                }
            }
        }
    }

    /// `SalusLineChart.kt:125` (`AREA_TOP_ALPHA`). A component constant, not a design token:
    /// `design-tokens.md` carries no alpha ramps and Android does not name this one either.
    private static let areaTopAlpha = 0.28

    // Swift Charts needs a name per plottable value; these never reach the screen (the legend is
    // hidden and the axis labels come from the model's own closures), they only keep the two
    // series apart so the marks are not joined into one line.
    private static let xSeriesId = "epochDay"
    private static let ySeriesId = "value"
    private static let seriesId = "series"
    private static let primarySeries = "primary"
    private static let secondarySeries = "secondary"
}

extension View {
    /// Applies an explicit x domain when there is one. A `nil` domain means the model carries no
    /// points — the chart is not shown in that state (`chartOrNull`'s two-point minimum), but a
    /// view has no say in that, and pinning an empty domain is what makes Swift Charts draw
    /// nothing at all rather than an empty grid.
    @ViewBuilder
    fileprivate func chartXScaleIfSet(_ domain: ClosedRange<Int>?) -> some View {
        if let domain {
            chartXScale(domain: domain)
        } else {
            self
        }
    }

    /// The y twin of ``chartXScaleIfSet(_:)``.
    @ViewBuilder
    fileprivate func chartYScaleIfSet(_ domain: ClosedRange<Float>?) -> some View {
        if let domain {
            chartYScale(domain: domain)
        } else {
            self
        }
    }

    /// Replaces the chart's own (unreadable) accessibility tree with one spoken summary, the twin
    /// of `Modifier.semantics { contentDescription = … }` (`SalusLineChart.kt:116-120`). A `nil`
    /// summary leaves the view untouched, exactly as the Kotlin `else` branch does.
    @ViewBuilder
    fileprivate func accessibilitySummary(_ summary: String?) -> some View {
        if let summary {
            accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(summary))
        } else {
            self
        }
    }
}

#Preview("Line chart") {
    SalusLineChart(
        model: ChartUiModel(
            points: [
                ChartPoint(xEpochDay: 20000, y: 72.4),
                ChartPoint(xEpochDay: 20003, y: 71.8),
                ChartPoint(xEpochDay: 20007, y: 71.1),
                ChartPoint(xEpochDay: 20012, y: 70.6)
            ],
            xLabel: { "\($0 - 20000) d" },
            yLabel: { String(format: "%.1f", $0) }
        ),
        contentDescription: "Latest weight 70.6 kilograms"
    )
    .frame(height: 220)
    .padding(SalusSpacing.lg)
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
}

#Preview("Two series, dark") {
    SalusLineChart(
        model: ChartUiModel(
            points: [
                ChartPoint(xEpochDay: 20000, y: 128),
                ChartPoint(xEpochDay: 20002, y: 124),
                ChartPoint(xEpochDay: 20005, y: 131)
            ],
            xLabel: { "\($0 - 20000) d" },
            secondaryPoints: [
                ChartPoint(xEpochDay: 20000, y: 82),
                ChartPoint(xEpochDay: 20002, y: 79),
                ChartPoint(xEpochDay: 20005, y: 84)
            ]
        )
    )
    .frame(height: 220)
    .padding(SalusSpacing.lg)
    .salusTheme(SalusTheme.resolve(systemIsDark: true))
}
