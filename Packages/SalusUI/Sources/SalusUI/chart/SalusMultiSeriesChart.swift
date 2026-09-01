// Ported from `core/ui/.../chart/SalusMultiSeriesChart.kt`.
//
// This file is the multi-line counterpart to `SalusLineChart`, existing for the same reason:
// the chart engine is an implementation detail, and it is a different engine on each platform —
// Vico there, Swift Charts here. `MultiSeriesChartUiModel` is the contract both sides speak.
//
// Vico concepts and what replaces them:
//
//   * `CartesianChartModelProducer` + `runTransaction` (`SalusMultiSeriesChart.kt:64-78`) push the
//     series into the chart asynchronously. Swift Charts is declarative — the marks ARE the data —
//     so the producer, the `LaunchedEffect` and the "skip when empty" guard all collapse into a
//     `ForEach` over the model.
//   * `ProvideVicoTheme(rememberM3VicoTheme())` (`:90`) hands Vico the Material scheme. Swift Charts
//     draws with what each mark is given, so the colors are named per mark from the resolved theme.
//   * `CartesianValueFormatter` (`:80-88`) becomes `AxisValueLabel`, calling the same `xLabel`
//     closure.
//   * `rememberVicoZoomState(initialZoom = Zoom.Content)` (`:126`) makes Vico open showing the whole
//     selected period. Swift Charts already plots the full domain in the available width; the twin of
//     "open on Content" is therefore to add no scroll modifier.
//
// Two things this chart deliberately does not do, both for the same reason the Kotlin records them
// (`SalusMultiSeriesChart.kt:38-50`) — the series carry no common unit, so there is nothing a y
// value could be measured in:
//
//   1. **No vertical axis.** A number on it would belong to none of the lines; the caller puts the
//      real values in a legend. Use `SalusLineChart` whenever one unit covers the whole chart.
//   2. **No area fill.** Overlapping translucent areas turn into a colour none of the lines actually
//      is, and the point of this chart is telling the lines apart.
//
// Every reading is marked with a point. That mirrors the Kotlin (`:47-50`): a series holding one
// reading has no segment to stroke, so without a point it would draw nothing — a blank chart under
// a legend naming two metrics. `SalusLineChart` escapes this only because its area fill still paints
// something, and this chart deliberately has no area fill.

#if canImport(Charts)
    import Charts
#endif
import SalusDesignSystem
import SwiftUI

/// Several lines over one shared x axis, one colour per `ChartSeries.role`.
///
/// The chart owns its own height, the way `SalusBarChart` does: callers position it, they do not
/// size it, so every chart in the app stays the same height without a value in a feature.
public struct SalusMultiSeriesChart: View {
    private let model: MultiSeriesChartUiModel
    private let contentDescription: String?

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - contentDescription: spoken summary of the chart; a chart is opaque to VoiceOver
    ///     exactly as it is to TalkBack (`SalusMultiSeriesChart.kt:55-57`).
    public init(model: MultiSeriesChartUiModel, contentDescription: String? = nil) {
        self.model = model
        self.contentDescription = contentDescription
    }

    public var body: some View {
        chart
            .frame(height: Self.chartHeight)
            // Vico draws no legend unless one is added (`SalusMultiSeriesChart.kt` adds none), and
            // Swift Charts synthesises one from the series ids, so it is turned off here.
            .chartLegend(.hidden)
            .accessibilitySummary(contentDescription)
    }

    private var chart: some View {
        Chart {
            seriesMarks
        }
        .chartXAxis { xAxis }
        // No vertical axis: a number on it could not belong to any of these unit-less series.
        .chartYAxis(.hidden)
    }

    @ChartContentBuilder
    private var seriesMarks: some ChartContent {
        ForEach(model.series) { series in
            ForEach(series.points, id: \.xEpochDay) { point in
                LineMark(
                    x: .value(Self.xSeriesId, point.xEpochDay),
                    y: .value(Self.ySeriesId, point.y),
                    series: .value(Self.seriesId, series.role.seriesName)
                )
                // The foreground style colours the line *and* its marks, so the two stay one
                // colour per role without naming it twice.
                .foregroundStyle(series.role.chartColor(theme: theme.colorScheme))
                // Every reading is marked with a dot (`SalusMultiSeriesChart.kt:98-106`), so a
                // single-reading series still draws rather than vanishing.
                .symbol(Circle())
                .symbolSize(CGSize(width: Self.pointSize, height: Self.pointSize))
            }
        }
    }

    /// `HorizontalAxis.rememberBottom(valueFormatter = bottomFormatter)`
    /// (`SalusMultiSeriesChart.kt:110`).
    private var xAxis: some AxisContent {
        AxisMarks(values: xAxisValues) { value in
            AxisGridLine()
            AxisTick()
            AxisValueLabel {
                if let epochDay = value.as(Int.self) {
                    Text(model.xLabel(epochDay))
                }
            }
        }
    }

    /// The epoch days the bottom axis labels — the days the series actually measure.
    private var xAxisValues: [Int] {
        Array(Set(model.series.flatMap(\.points).map(\.xEpochDay))).sorted()
    }

    /// `MultiSeriesChartHeight` (`SalusMultiSeriesChart.kt:156`) — matches `SalusBarChart`: tall
    /// enough to read a shape off, short enough to sit in a card.
    private static let chartHeight: CGFloat = 200

    /// `PointSize` (`SalusMultiSeriesChart.kt:159`) — reads as a marker on the line rather than
    /// as a bead threaded onto it.
    private static let pointSize: CGFloat = 6

    // Swift Charts needs a name per plottable value; these never reach the screen (the legend is
    // hidden and the axis labels come from the model's own closure).
    private static let xSeriesId = "epochDay"
    private static let ySeriesId = "value"
    private static let seriesId = "series"
}

extension SeriesRole {
    /// The Swift Charts series name for this role — a stable, comparable identifier (never the
    /// theme colour, which a mark cannot name) that keeps the two lines from being joined.
    fileprivate var seriesName: String {
        switch self {
        case .primary: "primary"
        case .secondary: "secondary"
        case .tertiary: "tertiary"
        }
    }

    /// The theme colour a series with this role is drawn in (`SeriesRole.chartColor()`,
    /// `SalusMultiSeriesChart.kt:147-153`). Single source of the mapping: the chart and the
    /// legend both read it, so a swatch cannot drift away from the line it stands for.
    fileprivate func chartColor(theme: SalusColorScheme) -> Color {
        switch self {
        case .primary: theme.primary
        case .secondary: theme.tertiary
        case .tertiary: theme.secondary
        }
    }
}

extension ChartSeries: Identifiable {
    /// An identity for `ForEach`: the series role, which every chart draws at most once.
    public var id: SeriesRole { role }
}

extension View {
    /// Replaces the chart's own (unreadable) accessibility tree with one spoken summary, the twin
    /// of `Modifier.semantics { contentDescription = … }` (`SalusMultiSeriesChart.kt:131-133`). A
    /// `nil` summary leaves the view untouched, exactly as the Kotlin `else` branch does.
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

#if canImport(Charts)
    #Preview("Overlay chart") {
        SalusMultiSeriesChart(
            model: MultiSeriesChartUiModel(
                series: [
                    ChartSeries(
                        points: [
                            ChartPoint(xEpochDay: 20000, y: 0.9),
                            ChartPoint(xEpochDay: 20003, y: 0.6),
                            ChartPoint(xEpochDay: 20007, y: 0.4)
                        ],
                        role: .primary
                    ),
                    ChartSeries(
                        points: [
                            ChartPoint(xEpochDay: 20000, y: 0.2),
                            ChartPoint(xEpochDay: 20003, y: 0.8),
                            ChartPoint(xEpochDay: 20007, y: 0.3)
                        ],
                        role: .secondary
                    )
                ],
                xLabel: { "\($0 - 20000) d" }
            ),
            contentDescription: "Weight and blood pressure shapes over time"
        )
        .padding(SalusSpacing.lg)
        .salusTheme(SalusTheme.resolve(systemIsDark: false))
    }

    #Preview("Overlay chart, dark") {
        SalusMultiSeriesChart(
            model: MultiSeriesChartUiModel(
                series: [
                    ChartSeries(
                        points: [
                            ChartPoint(xEpochDay: 20000, y: 0.9),
                            ChartPoint(xEpochDay: 20003, y: 0.6),
                            ChartPoint(xEpochDay: 20007, y: 0.4)
                        ],
                        role: .primary
                    ),
                    ChartSeries(
                        points: [
                            ChartPoint(xEpochDay: 20000, y: 0.2),
                            ChartPoint(xEpochDay: 20003, y: 0.8),
                            ChartPoint(xEpochDay: 20007, y: 0.3)
                        ],
                        role: .secondary
                    ),
                    ChartSeries(
                        points: [
                            ChartPoint(xEpochDay: 20000, y: 0.3),
                            ChartPoint(xEpochDay: 20003, y: 0.5),
                            ChartPoint(xEpochDay: 20007, y: 0.7)
                        ],
                        role: .tertiary
                    )
                ],
                xLabel: { "\($0 - 20000) d" }
            )
        )
        .padding(SalusSpacing.lg)
        .salusTheme(SalusTheme.resolve(systemIsDark: true))
    }
#endif
