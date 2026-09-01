// Ported 1:1 from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/chart/MultiSeriesChartUiModel.kt`.
//
// The same two Kotlin drops recorded in `ChartUiModel.swift`: `@Immutable` is a Compose promise a
// Swift `struct` enforces by construction, and `ImmutableList` is a Kotlin view-onto-mutable-list
// concern a Swift `Array` value does not have.

/// Which of the theme's chart colours a series is drawn in (`MultiSeriesChartUiModel.kt:15-19`).
///
/// A role rather than a `Color`, so callers never name a colour: the mapping to the theme lives
/// in one place in this module, which is what keeps a chart and its legend in step and keeps
/// hardcoded colours out of feature modules.
///
/// The order is the order series should be assigned, most prominent first.
public enum SeriesRole: Sendable, Equatable, Hashable, CaseIterable {
    case primary
    case secondary
    case tertiary
}

/// One line of a `MultiSeriesChartUiModel`, with the role that gives it its colour
/// (`MultiSeriesChartUiModel.kt:22-26`).
public struct ChartSeries: Equatable, Sendable {
    public let points: [ChartPoint]
    public let role: SeriesRole

    public init(points: [ChartPoint], role: SeriesRole) {
        self.points = points
        self.role = role
    }
}

/// Chart-engine-agnostic input for several lines sharing one x axis
/// (`MultiSeriesChartUiModel.kt:32-48`).
///
/// Distinct from `ChartUiModel` rather than an extension of it, because the two answer different
/// questions. `ChartUiModel` draws one measurement — optionally as a pair, like systolic over
/// diastolic — against a labelled y axis in that measurement's own unit. This model draws
/// several *different* measurements together, which only works once the caller has put them on
/// a common scale, and at that point there is no unit left for a y axis to be labelled in. That
/// is why there is no `yLabel` here and why `SalusMultiSeriesChart` draws no vertical axis:
/// a number on it could not honestly belong to any of the series.
///
/// The caller keeps the real values and shows them some other way — a legend line, usually.
///
/// Deliberately **not** `Equatable`: the `xLabel` closure cannot be compared, exactly as
/// `ChartUiModel` records for its own labels. `ChartSeries` carries the comparable state, and
/// SwiftUI redraws the chart from the arrays.
public struct MultiSeriesChartUiModel: Sendable {
    /// Series drawn in the order given; the first is the topmost line.
    public let series: [ChartSeries]
    /// The caption for an epoch day on the bottom axis, already localized.
    public let xLabel: @Sendable (Int) -> String

    public init(
        series: [ChartSeries],
        xLabel: @escaping @Sendable (Int) -> String
    ) {
        self.series = series
        self.xLabel = xLabel
    }
}
