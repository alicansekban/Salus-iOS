// Ported from `core/ui/.../chart/SalusBarChart.kt:56-148`.
//
// This file is the categorical counterpart to `SalusLineChart`, and it exists for the same
// reason: the chart engine is an implementation detail, and it is a different engine on each
// platform — Vico there, Swift Charts here. `BarChartUiModel` is the contract both sides speak.
//
// Vico concepts and what replaces them:
//
//   * `CartesianChartModelProducer` + `runTransaction` (`SalusBarChart.kt:60-81`) push columns
//     into the chart asynchronously. Swift Charts is declarative — the marks ARE the data — so
//     the producer, the `LaunchedEffect` and the "skip the transaction when empty" guard all
//     collapse into `ForEach` over the model.
//   * `ProvideVicoTheme(rememberM3VicoTheme())` (`:108`) hands Vico the Material scheme. Swift
//     Charts draws with what each mark is given, so the colors are named per mark from the
//     resolved theme.
//   * `CartesianValueFormatter` (`:89-106`) becomes `AxisValueLabel`, calling the same two
//     closures.
//   * `rememberVicoZoomState(initialZoom = Zoom.Content)` (`:135`) makes Vico open showing the
//     whole selected period. Swift Charts already plots the full domain in the available width;
//     the twin of "open on Content" is therefore to add no scroll modifier.
//
// The bottom-axis label is total here too, but for a different reason than Vico's: Swift Charts
// `AxisMarks(values:)` labels exactly the values it is given, so the bars' own indices are
// passed and every tick lands on a real column. The `barAxisLabel` clamping Vico needed
// (`SalusBarChart.kt:161-164`) has no Swift Charts twin and is dropped.

#if canImport(Charts)
    import Charts
#endif
import SalusDesignSystem
import SwiftUI

/// The one bar chart in the app. Feature screens pass a `BarChartUiModel` and never see the
/// engine.
public struct SalusBarChart: View {
    private let model: BarChartUiModel
    private let contentDescription: String?

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - contentDescription: spoken summary of the chart; a chart is opaque to VoiceOver
    ///     exactly as it is to TalkBack (`SalusBarChart.kt:51-52`).
    public init(model: BarChartUiModel, contentDescription: String? = nil) {
        self.model = model
        self.contentDescription = contentDescription
    }

    public var body: some View {
        chart
            .chartYAxis { yAxis }
            .chartLegend(.hidden)
            .accessibilitySummary(contentDescription)
    }

    /// `MaterialTheme.colorScheme.primary` (`SalusBarChart.kt:83`).
    private var primaryColor: Color { theme.colorScheme.primary }

    /// `MaterialTheme.salusColors.metricDown` (`SalusBarChart.kt:86`) — M15 moved the second
    /// column off `tertiary` onto the rose that means "the other one" app-wide, the same token
    /// `SalusLineChart`'s second series uses, so a colour never changes meaning between the two
    /// charts. The value is `tertiary` in every palette; the role is what moved.
    private var secondaryColor: Color { theme.extendedColors.metricDown }

    private var chart: some View {
        Chart {
            ForEach(Array(model.bars.enumerated()), id: \.offset) { index, bar in
                BarMark(
                    x: .value(Self.xSeriesId, index),
                    y: .value(Self.ySeriesId, bar.value)
                )
                .foregroundStyle(primaryColor)
                .cornerRadius(SalusBarChartDefaults.cornerRadius)

                if let secondaryValue = bar.secondaryValue {
                    BarMark(
                        x: .value(Self.xSeriesId, index),
                        y: .value(Self.ySeriesId, secondaryValue)
                    )
                    .foregroundStyle(secondaryColor)
                    .cornerRadius(SalusBarChartDefaults.cornerRadius)
                }
            }
        }
        .chartXAxis { xAxis }
    }

    /// The bottom axis turns each bar's index back into the caller's label (`SalusBarChart.kt:89-96`).
    private var xAxis: some AxisContent {
        AxisMarks(values: model.bars.indices.map { Double($0) }) { value in
            AxisGridLine().foregroundStyle(ChartAxisStyle.gridColor(theme))
            AxisTick().foregroundStyle(ChartAxisStyle.gridColor(theme))
            AxisValueLabel {
                if let index = value.as(Int.self), model.bars.indices.contains(index) {
                    Text(model.bars[index].label).salusChartAxisLabel(theme: theme)
                }
            }
        }
    }

    /// `VerticalAxis.rememberStart(valueFormatter = startFormatter)` (`SalusBarChart.kt:98-106`) —
    /// "start" is the leading edge, which is `.leading` here.
    private var yAxis: some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisGridLine().foregroundStyle(ChartAxisStyle.gridColor(theme))
            AxisTick().foregroundStyle(ChartAxisStyle.gridColor(theme))
            AxisValueLabel {
                if let y = value.as(Double.self) {
                    Text(model.yLabel(Float(y))).salusChartAxisLabel(theme: theme)
                }
            }
        }
    }

    // Swift Charts needs a name per plottable value; these never reach the screen (the legend is
    // hidden and the axis labels come from the model's own closures).
    private static let xSeriesId = "index"
    private static let ySeriesId = "value"
}

/// The bar chart's own dimensions.
public enum SalusBarChartDefaults {
    /// `columnShape = MaterialTheme.shapes.extraSmall` (`SalusBarChart.kt:87`) — a shape token, so
    /// the radius is read from `SalusShapes` rather than spelled as a number here.
    public static let cornerRadius: CGFloat = SalusShapes.extraSmall
}

extension View {
    /// Replaces the chart's own (unreadable) accessibility tree with one spoken summary, the twin
    /// of `Modifier.semantics { contentDescription = … }` (`SalusBarChart.kt:140-144`). A `nil`
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

#if canImport(Charts)
    #Preview("Bar chart") {
        SalusPreviewPalettes {
            VStack(spacing: SalusSpacing.lg) {
                SalusBarChart(
                    model: BarChartUiModel(
                        bars: [
                            BarEntry(label: "Morning", value: 125),
                            BarEntry(label: "Midday", value: 118),
                            BarEntry(label: "Evening", value: 131)
                        ],
                        yLabel: { String(format: "%.0f", $0) }
                    ),
                    contentDescription: "Morning 125, midday 118, evening 131"
                )
                .frame(height: 200)

                // Grouped: `primary` and the `metricDown` rose, so a palette that collapses the
                // two into one colour is visible at a glance.
                SalusBarChart(
                    model: BarChartUiModel(
                        bars: [
                            BarEntry(label: "Morning", value: 125, secondaryValue: 82),
                            BarEntry(label: "Midday", value: 118, secondaryValue: 79),
                            BarEntry(label: "Evening", value: 131, secondaryValue: 84)
                        ],
                        yLabel: { String(format: "%.0f", $0) }
                    )
                )
                .frame(height: 200)
            }
        }
    }
#endif
