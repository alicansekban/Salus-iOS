// Ported 1:1 from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/chart/BarChartUiModel.kt`.
//
// The two Kotlin mechanisms dropped here are the same two `ChartUiModel` drops: `@Immutable` is
// a Compose promise a Swift `struct` enforces by construction, and `ImmutableList` is a Kotlin
// view-onto-mutable-list concern a Swift `Array` value does not have.

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

    /// - Parameters:
    ///   - yLabel: defaults to the plain number, the twin of Kotlin's `{ it.toString() }`
    ///     (`BarChartUiModel.kt:33`) — `70.5` reads "70.5" and `70` reads "70.0" on both platforms.
    public init(
        bars: [BarEntry],
        yLabel: @escaping @Sendable (Float) -> String = { String(describing: $0) }
    ) {
        self.bars = bars
        self.yLabel = yLabel
    }
}
