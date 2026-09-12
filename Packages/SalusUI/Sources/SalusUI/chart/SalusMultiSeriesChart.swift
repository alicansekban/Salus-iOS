// Ported from `core/ui/.../chart/SalusMultiSeriesChart.kt`.
//
// This file is the multi-line counterpart to `SalusLineChart`, existing for the same reason:
// the chart engine is an implementation detail, and it is a different engine on each platform —
// Vico there, Swift Charts here. `MultiSeriesChartUiModel` is the contract both sides speak.
//
// Vico concepts and what replaces them:
//
//   * `CartesianChartModelProducer` + `runTransaction` (`SalusMultiSeriesChart.kt:73-87`) push the
//     series into the chart asynchronously. Swift Charts is declarative — the marks ARE the data —
//     so the producer, the `LaunchedEffect` and the "skip when empty" guard all collapse into a
//     `ForEach` over the model.
//   * `ProvideVicoTheme(rememberM3VicoTheme())` (`:99`) hands Vico the Material scheme. Swift Charts
//     draws with what each mark is given, so the colors are named per mark from the resolved theme.
//   * `CartesianValueFormatter` (`:89-97`) becomes `AxisValueLabel`, calling the same `xLabel`
//     closure.
//   * `rememberVicoZoomState(initialZoom = Zoom.Content)` (`:135`) makes Vico open showing the whole
//     selected period. Swift Charts already plots the full domain in the available width; the twin of
//     "open on Content" is therefore to add no scroll modifier.
//
// Two things this chart deliberately does not do, both for the same reason the Kotlin records them
// (`SalusMultiSeriesChart.kt:47-59`) — the series carry no common unit, so there is nothing a y
// value could be measured in:
//
//   1. **No vertical axis.** A number on it would belong to none of the lines; the caller puts the
//      real values in a legend. Use `SalusLineChart` whenever one unit covers the whole chart.
//   2. **No area fill.** Overlapping translucent areas turn into a colour none of the lines actually
//      is, and the point of this chart is telling the lines apart.
//
// Every reading is marked with a point. That mirrors the Kotlin (`:56-59`): a series holding one
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
    ///     exactly as it is to TalkBack (`SalusMultiSeriesChart.kt:64-65`).
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
                .foregroundStyle(series.role.chartColor(theme: theme))
                // Every reading is marked with a dot (`SalusMultiSeriesChart.kt:107-114`), so a
                // single-reading series still draws rather than vanishing.
                .symbol(Circle())
                .symbolSize(CGSize(width: Self.pointSize, height: Self.pointSize))
            }
        }
    }

    /// `HorizontalAxis.rememberBottom(valueFormatter = bottomFormatter)`
    /// (`SalusMultiSeriesChart.kt:126`).
    private var xAxis: some AxisContent {
        AxisMarks(values: xAxisValues) { value in
            AxisGridLine().foregroundStyle(ChartAxisStyle.gridColor(theme))
            AxisTick().foregroundStyle(ChartAxisStyle.gridColor(theme))
            AxisValueLabel {
                if let epochDay = value.as(Int.self) {
                    Text(model.xLabel(epochDay)).salusChartAxisLabel(theme: theme)
                }
            }
        }
    }

    /// The epoch days the bottom axis labels — the days the series actually measure.
    private var xAxisValues: [Int] {
        Array(Set(model.series.flatMap(\.points).map(\.xEpochDay))).sorted()
    }

    /// `MultiSeriesChartHeight` (`SalusMultiSeriesChart.kt:165`) — matches `SalusBarChart`: tall
    /// enough to read a shape off, short enough to sit in a card.
    private static let chartHeight: CGFloat = 200

    /// `PointSize` (`SalusMultiSeriesChart.kt:168`) — reads as a marker on the line rather than
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
    /// `SalusMultiSeriesChart.kt:158-161`). Single source of the mapping: the chart and the
    /// legend both read it, so a swatch cannot drift away from the line it stands for.
    ///
    /// M15 moved the second and third roles off the raw Material roles: `secondary` takes the
    /// `metricDown` rose that means "the other one" app-wide (the same token `SalusLineChart` and
    /// `SalusBarChart` give their second series), and `tertiary` takes the trends feature accent,
    /// so a third line reads as the feature it belongs to rather than as a spare palette slot.
    fileprivate func chartColor(theme: SalusResolvedTheme) -> Color {
        switch self {
        case .primary: theme.colorScheme.primary
        case .secondary: theme.extendedColors.metricDown
        case .tertiary: theme.extendedColors.trends.accent
        }
    }
}

extension ChartSeries: Identifiable {
    /// An identity for `ForEach`: the series role, which every chart draws at most once.
    public var id: SeriesRole { role }
}

extension View {
    /// Replaces the chart's own (unreadable) accessibility tree with one spoken summary, the twin
    /// of `Modifier.semantics { contentDescription = … }` (`SalusMultiSeriesChart.kt:139-144`). A
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
        SalusPreviewPalettes {
            // Three roles at once: `primary`, the `metricDown` rose and the trends accent — the
            // three colours a palette has to keep apart for this chart to be readable at all.
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
                ),
                contentDescription: "Weight and blood pressure shapes over time"
            )
        }
    }
#endif
