// Ported 1:1 from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/chart/BarChartUiModel.kt`.
//
// The two Kotlin mechanisms dropped here are the same two `ChartUiModel` drops: `@Immutable` is
// a Compose promise a Swift `struct` enforces by construction, and `ImmutableList` is a Kotlin
// view-onto-mutable-list concern a Swift `Array` value does not have.
//
// iOS-M17 Task 11 adds `BarChartUiModel.baseline` and `BarBaseline`, the twin of Android's
// `BarBaseline` from the same task: a labelled dashed reference line across the chart (REDUCE's
// "old average").

/// One column of a bar chart (`BarChartUiModel.kt:18-22`).
///
/// `label` is the axis caption, already localized by the caller — this module holds no strings
/// of its own. `secondaryValue` is an optional second column drawn next to the first in a
/// secondary color (diastolic beside systolic); leave it `nil` for a single-series chart.
///
/// Set `secondaryValue` on every bar of a model or on none of them. A partly populated second
/// series would cover fewer x values than the first, and how the underlying grouped column
/// layer renders that is not something callers should be relying on.
public struct BarEntry: Equatable, Sendable {
    public let label: String
    public let value: Float
    public let secondaryValue: Float?

    public init(label: String, value: Float, secondaryValue: Float? = nil) {
        self.label = label
        self.value = value
        self.secondaryValue = secondaryValue
    }
}

/// Chart-engine-agnostic bar chart input, the categorical counterpart to `ChartUiModel`
/// (`BarChartUiModel.kt:31-33`).
///
/// The x axis is the position of the bar in `bars`, so categories need no numeric identity and
/// the same model feeds Swift Charts on iOS.
///
/// Deliberately **not** `Equatable`: the `yLabel` closure cannot be compared, exactly as
/// `ChartUiModel` records for its own labels. Nothing needs it — `BarEntry` carries the
/// comparable state, and SwiftUI redraws the chart from the array.
public struct BarChartUiModel: Sendable {
    public let bars: [BarEntry]
    public let yLabel: @Sendable (Float) -> String
    /// A dashed horizontal reference line (iOS-M17 Task 11). Additive: every existing call site
    /// omits it, and a chart without one is drawn exactly as before.
    public let baseline: BarBaseline?

    /// - Parameters:
    ///   - yLabel: defaults to the plain number, the twin of Kotlin's `{ it.toString() }`
    ///     (`BarChartUiModel.kt:33`) — `70.5` reads "70.5" and `70` reads "70.0" on both platforms.
    public init(
        bars: [BarEntry],
        yLabel: @escaping @Sendable (Float) -> String = { String(describing: $0) },
        baseline: BarBaseline? = nil
    ) {
        self.bars = bars
        self.yLabel = yLabel
        self.baseline = baseline
    }
}

/// A labelled horizontal reference line across a bar chart — the REDUCE "old average". The chart
/// widens its range to include `value`, so the line is always on the canvas. `label` is optional: a
/// caller that must not caption the line passes `nil` (or no baseline at all).
public struct BarBaseline: Equatable, Sendable {
    public let value: Float
    public let label: String?

    public init(value: Float, label: String? = nil) {
        self.value = value
        self.label = label
    }
}

/// The y range a bar chart is plotted in when it has a baseline.
enum BarChartRange {
    /// Headroom over the tallest of the bars and the baseline, so the baseline's caption has room
    /// above its line (Android `BaselineHeadroom`).
    static let baselineHeadroom: Float = 1.2

    /// The top of the plotted range when a baseline is set, else `nil` — the chart then keeps Swift
    /// Charts' own range, so a chart without a baseline is drawn exactly as before. The larger of
    /// the tallest bar (either series) and the baseline, times the headroom (Android `barChartMaxY`).
    static func maxY(bars: [BarEntry], baseline: BarBaseline?) -> Double? {
        guard let baseline else { return nil }
        let tallest = bars.map { max($0.value, $0.secondaryValue ?? 0) }.max() ?? 0
        return Double(max(tallest, baseline.value) * baselineHeadroom)
    }
}
