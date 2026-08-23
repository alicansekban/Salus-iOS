// Ported 1:1 from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/chart/ChartUiModel.kt:1-28`.
//
// Two Kotlin mechanisms have no Swift twin and are dropped rather than imitated:
//
//   * `@Immutable` (`ChartUiModel.kt:11`, `:22`) is a Compose promise that a *class* never changes
//     under the recomposer. A Swift `struct` is that promise, enforced by the language, so the
//     annotation has nothing left to say.
//   * `ImmutableList` (kotlinx.collections.immutable) exists because a Kotlin `List` is a view onto
//     a possibly-mutable backing list. A Swift `Array` is a value; passing one hands over a copy.
//
// The labels stay closures, exactly as Kotlin has them: the chart is rendered by `SalusUI` but the
// axis text belongs to the feature, which is the only layer that knows the locale format and the
// unit. They are `@Sendable` so the model can cross an isolation boundary intact.

/// Chart-engine-agnostic line chart input. The x axis is a day index (epoch day) so values
/// stay small and precise; the same model feeds Vico on Android (`ChartUiModel.kt:7-9`).
public struct ChartPoint: Hashable, Sendable {
    public let xEpochDay: Int
    public let y: Float

    public init(xEpochDay: Int, y: Float) {
        self.xEpochDay = xEpochDay
        self.y = y
    }
}

/// `points` is the primary series; `secondaryPoints` is an optional second series rendered
/// in a secondary color (e.g. diastolic under systolic). Existing single-series call sites
/// are unaffected by the default (`ChartUiModel.kt:17-20`).
///
/// Deliberately **not** `Equatable`: Kotlin's `data class` compares the two label lambdas by
/// reference, which is neither meaningful nor reproducible, and Swift closures cannot be compared
/// at all. Nothing needs it — `ChartPoint` carries the comparable state, and SwiftUI redraws the
/// chart from the arrays.
public struct ChartUiModel: Sendable {
    public let points: [ChartPoint]
    public let xLabel: @Sendable (Int) -> String
    public let yLabel: @Sendable (Float) -> String
    public let secondaryPoints: [ChartPoint]

    /// - Parameters:
    ///   - yLabel: defaults to the plain number, the twin of Kotlin's `{ it.toString() }`
    ///     (`ChartUiModel.kt:26`) — `70.5` reads "70.5" and `70` reads "70.0" on both platforms.
    public init(
        points: [ChartPoint],
        xLabel: @escaping @Sendable (Int) -> String,
        yLabel: @escaping @Sendable (Float) -> String = { String(describing: $0) },
        secondaryPoints: [ChartPoint] = []
    ) {
        self.points = points
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.secondaryPoints = secondaryPoints
    }
}
