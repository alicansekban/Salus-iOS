// Ported from `core/ui/.../chart/SalusLineChart.kt:68-213`.
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
//
// M15 hung a halo under the line: a second Vico *layer*, registered before the line layer
// (`SalusLineChart.kt:97,118-128,191`), stroking the same series in `accentGlow` at `GlowThickness`
// under the `LineThickness` line. Vico draws layers in registration order and Swift Charts draws
// marks in declaration order, so the port is simply to declare the glow's `LineMark` first; the
// area fill and the line, one Vico layer there, follow it here in that order.
//
// Vico's press marker (`SalusLineChart.kt:159-178`) has no twin here and this file does not add
// one: a marker is an interaction rather than a style, and the port has never had it.

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

    /// `MaterialTheme.salusColors.metricDown` (`SalusLineChart.kt:96`). M15 moved the second
    /// series off `tertiary` onto the rose that means "the other one" app-wide — the same token a
    /// negative delta and `SalusBarChart`'s second column use — so a colour never changes meaning
    /// between two charts. The value is `tertiary` in every palette; the role is what moved.
    private var secondaryColor: Color { theme.extendedColors.metricDown }

    /// `MaterialTheme.salusColors.accentGlow` (`SalusLineChart.kt:97`) — `primary` at 24 % dark /
    /// 16 % light, so the halo reads as light around the line rather than as a second line.
    private var glowColor: Color { theme.extendedColors.accentGlow }

    /// Grid lines and ticks. Vico gets `outlineVariant` from `rememberM3VicoTheme()`
    /// (`SalusLineChart.kt:117`); Swift Charts has no theme to hand a scheme to, so the role is
    /// named per axis here.
    private var gridColor: Color { theme.colorScheme.outlineVariant }

    private var chart: some View {
        Chart {
            glowMarks
            areaMarks
            primaryMarks
            secondaryMarks
        }
    }

    /// The halo, declared **first** so everything else lands on top of it — the order Vico gets by
    /// registering `glowLayer` before `lineLayer` (`SalusLineChart.kt:118-128,191`).
    @ChartContentBuilder
    private var glowMarks: some ChartContent {
        ForEach(model.points, id: \.xEpochDay) { point in
            LineMark(
                x: .value(Self.xSeriesId, point.xEpochDay),
                y: .value(Self.ySeriesId, point.y),
                series: .value(Self.seriesId, Self.glowSeries)
            )
            .foregroundStyle(glowColor)
            .lineStyle(glowStroke)
        }
    }

    /// Gradient area under the line, fading to transparent (`SalusLineChart.kt:138-148`). Part of
    /// Vico's line layer, so it is drawn over the glow and under the line.
    @ChartContentBuilder
    private var areaMarks: some ChartContent {
        ForEach(model.points, id: \.xEpochDay) { point in
            AreaMark(
                x: .value(Self.xSeriesId, point.xEpochDay),
                y: .value(Self.ySeriesId, point.y)
            )
            .foregroundStyle(areaGradient)
        }
    }

    @ChartContentBuilder
    private var primaryMarks: some ChartContent {
        ForEach(model.points, id: \.xEpochDay) { point in
            LineMark(
                x: .value(Self.xSeriesId, point.xEpochDay),
                y: .value(Self.ySeriesId, point.y),
                series: .value(Self.seriesId, Self.primarySeries)
            )
            .foregroundStyle(primaryColor)
            .lineStyle(lineStroke)
        }
    }

    @ChartContentBuilder
    private var secondaryMarks: some ChartContent {
        ForEach(model.secondaryPoints, id: \.xEpochDay) { point in
            LineMark(
                x: .value(Self.xSeriesId, point.xEpochDay),
                y: .value(Self.ySeriesId, point.y),
                series: .value(Self.seriesId, Self.secondarySeries)
            )
            .foregroundStyle(secondaryColor)
            .lineStyle(lineStroke)
        }
    }

    /// `LineStroke.Continuous(thickness = GlowThickness, cap = StrokeCap.Round)`
    /// (`SalusLineChart.kt:121-125`).
    private var glowStroke: StrokeStyle {
        StrokeStyle(lineWidth: SalusLineChartDefaults.glowWidth, lineCap: .round, lineJoin: .round)
    }

    /// `LineStroke.Continuous(thickness = LineThickness, cap = StrokeCap.Round)`
    /// (`SalusLineChart.kt:132-136`).
    private var lineStroke: StrokeStyle {
        StrokeStyle(lineWidth: SalusLineChartDefaults.lineWidth, lineCap: .round, lineJoin: .round)
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [
                primaryColor.opacity(SalusLineChartDefaults.areaTopAlpha),
                primaryColor.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// `HorizontalAxis.rememberBottom(valueFormatter = bottomFormatter)` (`SalusLineChart.kt:106`),
    /// with the mark positions coming from the data rather than from Swift Charts' round numbers —
    /// see `ChartAxisScale.xAxisValues(for:)` for how that lines up with Vico's item placer.
    private var xAxis: some AxisContent {
        AxisMarks(values: ChartAxisScale.xAxisValues(for: model)) { value in
            AxisGridLine().foregroundStyle(gridColor)
            AxisTick().foregroundStyle(gridColor)
            // The first and last marks sit exactly on the plot edges, because the domain is the
            // data's own range. A centred label there would hang half outside the chart, and Swift
            // Charts drops rather than clips it — the last date simply vanished. Anchoring the
            // extremes inwards is Vico's `shiftExtremeLines` idea applied to the labels.
            AxisValueLabel(anchor: Self.labelAnchor(at: value.index, of: value.count)) {
                if let epochDay = value.as(Int.self) {
                    // `labelSmall` on `onSurfaceVariant` — what `rememberM3VicoTheme()` gives Vico's
                    // axis text (`SalusLineChart.kt:117`).
                    Text(model.xLabel(epochDay))
                        .font(SalusTypography.labelSmall.font)
                        .tracking(SalusTypography.labelSmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
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
            AxisGridLine().foregroundStyle(gridColor)
            AxisTick().foregroundStyle(gridColor)
            AxisValueLabel {
                if let y = value.as(Double.self) {
                    Text(model.yLabel(Float(y)))
                        .font(SalusTypography.labelSmall.font)
                        .tracking(SalusTypography.labelSmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }

    // Swift Charts needs a name per plottable value; these never reach the screen (the legend is
    // hidden and the axis labels come from the model's own closures), they only keep the three
    // lines apart so the marks are not joined into one.
    private static let xSeriesId = "epochDay"
    private static let ySeriesId = "value"
    private static let seriesId = "series"
    private static let glowSeries = "glow"
    private static let primarySeries = "primary"
    private static let secondarySeries = "secondary"
}

/// The line chart's own dimensions. Component constants the Kotlin file spells inline, not
/// `design-tokens.md` tokens — which is why they live here rather than in `SalusDesignSystem`.
public enum SalusLineChartDefaults {
    /// `LineThickness` (`SalusLineChart.kt:258`) — the visible line.
    public static let lineWidth: CGFloat = 2.5
    /// `GlowThickness` (`SalusLineChart.kt:261`) — the halo: wide enough to read as light around
    /// the line rather than as a second line.
    public static let glowWidth: CGFloat = 6
    /// `AreaTopAlpha` (`SalusLineChart.kt:252`) — the share of the line colour the area fill starts
    /// at, directly under the line. M15 took it from 0.28 to 0.24: the halo now carries part of the
    /// brightness the area used to carry alone.
    public static let areaTopAlpha = 0.24
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
    SalusPreviewPalettes {
        VStack(spacing: SalusSpacing.lg) {
            // One series: the glow reads as light under the line, and the area fill under both.
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
            .frame(height: 200)

            // Two series: `primary` over the halo, `metricDown` for the second reading.
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
            .frame(height: 200)
        }
    }
}
