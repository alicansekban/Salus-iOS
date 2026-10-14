// Ported from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/analysis/SmokingTrends.kt`
// and the integer half of `ui/SmokingTrendsModel.kt` (the reduction curve is `ReductionChartModel`).
//
// The premium "Sigara" section is `SmokingInsights` untouched — Android copies it into an
// `ImmutableList` twin for Compose's skipping, which a Swift value type does not need — so the only
// logic here is whether the section exists at all, and the plain functions from the insights'
// integers to what the cards draw. Like `barChartModelOf` they are functions rather than blocks in
// a view so the rules are covered by unit tests instead of by looking at a device. Captions and
// labels are catalog strings and so belong to the views; every function here takes them as
// arguments or leaves them out.

import Foundation
import SalusSmoking

/// The smoking section of the Trends screen, or `nil` when there is nothing to build it on.
///
/// `nil` is "no plan": a user who never set tracking up has no section at all, and the card stack
/// simply does not draw it. A plan with too few days behind it is a *present* section whose
/// `hasEnoughData` is false, because the screen has something honest to say there — the threshold.
///
/// The figures are `SmokingInsightsCalculator`'s, computed once here so the screen is handed a
/// finished answer. `nowMs` and `zone` come from the clock the caller owns; nothing in here reads
/// one. They cover the calculator's 30-day window whatever range the chips say, because the rule
/// that decides "enough data" is written against that window.
func smokingTrendsOrNull(_ input: SmokingInput, nowMs: Int64, zone: TimeZone) -> SmokingInsights? {
    guard input.plan != nil else { return nil }
    return SmokingInsightsCalculator.insights(input, nowMs: nowMs, zone: zone)
}

/// One trigger's row: which trigger, its share, and how full its bar is.
struct TriggerBar: Equatable {
    let trigger: CravingTrigger
    let permille: Int
    let progress: Double
}

/// One bar per trigger share, in the order the calculator ranked them.
func triggerBarsOf(_ shares: [TriggerShare]) -> [TriggerBar] {
    shares.map { share in
        TriggerBar(trigger: share.trigger, permille: share.permille, progress: Double(share.permille) / 1000)
    }
}

/// A permille share as the whole percentage it is written as, rounded half up. A tenth of a percent
/// is noise on a month of cravings, and the rounding is spelled out so that 34.5 % reads as 35 on
/// every platform.
func percentOf(_ permille: Int) -> Int {
    (permille + 5) / 10
}

/// Rows of the craving heatmap: one per `HourBand`.
let heatmapRows = 7

/// Columns of the craving heatmap: ISO weekdays, Monday first.
let heatmapColumns = 7

/// The heatmap's counts as the exact `heatmapRows` by `heatmapColumns` grid the component draws.
///
/// The calculator already produces this shape; the padding exists so that a short or empty input
/// degrades to empty cells at the right coordinates instead of shifting a column — a count under the
/// wrong weekday is a wrong claim, an empty cell is only an absence.
func heatmapValuesOf(_ heatmap: [[Int]]) -> [[Int]] {
    (0 ..< heatmapRows).map { row in
        (0 ..< heatmapColumns).map { column in
            heatmap.indices.contains(row) && heatmap[row].indices.contains(column) ? heatmap[row][column] : 0
        }
    }
}

/// One attempt's row: its 1-based number, its whole days, and its length against the longest.
struct AttemptBar: Equatable {
    let ordinal: Int
    let days: Int
    let progress: Double
}

/// The attempts compared by length, in the order they happened.
///
/// Days are whole days, so an attempt five hours into its 43rd day is 42, and the bar is measured in
/// those same whole days against the longest attempt: the bar and the number beside it can never
/// disagree. When no attempt has reached a full day yet the bars draw empty instead of dividing by
/// zero.
func attemptBarsOf(_ durations: [AttemptDuration]) -> [AttemptBar] {
    let days = durations.map { Int($0.durationMs / 86_400_000) }
    let longest = days.max() ?? 0
    return days.enumerated().map { index, wholeDays in
        AttemptBar(
            ordinal: index + 1,
            days: wholeDays,
            progress: longest <= 0 ? 0 : Double(wholeDays) / Double(longest)
        )
    }
}
