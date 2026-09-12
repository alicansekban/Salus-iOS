// The private companion half of `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/
// vitals/ui/list/VitalsViewModel.kt` (`:264-286`): one row's direction against the reading before
// it, and the band that decides when a move is only day-to-day variation.
//
// Its own file rather than a third extension on `VitalsViewModel`, because `VitalsStateBuilders`
// is already at the size the plan wants and this is a pure two-argument function that belongs to
// no instance. Kotlin keeps it `private` inside the class; nothing outside this package can name
// it here either.

import SalusModel

/// Direction of one row's change against the `previous` reading, with the same relative band
/// `MetricStats.trendOf` applies to a whole series: a move under ``VitalsRowTrend/band`` of the
/// previous value is day-to-day variation and reads as `.stable` (`VitalsViewModel.kt:264-279`).
///
/// The direction is all this says. A rise is not "worse" and a fall is not "better" for any of
/// these metrics, so nothing downstream may colour it as a verdict.
enum VitalsRowTrend {
    /// Mirrors the band `MetricStats` uses, so a row and a summary never disagree
    /// (`VitalsViewModel.kt:284-285`).
    static let band = 0.05

    /// `VitalsViewModel.kt:272-279`.
    static func of(delta: Double, previous: Double) -> Trend {
        let tolerance = abs(previous) * band
        if delta > tolerance {
            return .rising
        }
        if delta < -tolerance {
            return .falling
        }
        return .stable
    }
}
