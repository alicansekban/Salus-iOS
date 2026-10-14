// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// ReduceView.kt`.
//
// Everything the REDUCE body draws, decided from the snapshot alone, so the rules (which part
// shows, where the ring stops, what a vape hides) are plain logic and not view code.
//
// Counts are `Int` here because they are drawn as digits; the snapshot keeps them `Int64`.

import SalusSmoking

private let permille: Int64 = 1000

/// How today stands against the daily limit. It picks the copy, never a colour (review R2).
enum ReduceTone: Equatable {
    case empty
    case under
    case at
    case over
}

/// One slot of the 7-day chart. `units` is `nil` for a day with no data, which is not a zero.
struct ReduceBar: Equatable {
    let epochDay: Int64
    let units: Int64?
}

struct ReduceView: Equatable {
    let tone: ReduceTone
    let todayUnits: Int
    let limit: Int
    /// The ring's fill: today's share of the limit, held at 1000 once the limit is reached.
    let progressPermille: Int
    /// How far past full the ring went, 1000 = one extra lap; zero unless over the limit.
    let overflowPermille: Int
    /// Units over the limit, for the "+n" chip; the real number even when the arc is capped.
    let overBy: Int
    let remaining: Int
    /// "Bugün hiç içmedim" shows only while the day has no entry at all.
    let showNoneToday: Bool
    /// Over the limit but still under the old average: the supportive comparison, in units.
    let belowBaseline: Int?
    let bars: [ReduceBar]
    /// The "Eski ortalaman" marker. `nil` for a vape (contract 8.12): one session a day is no average.
    let baseline: Int?
    /// `nil` for a vape: its weekly card is money only.
    let weekReductionUnits: Int64?
    let weekSavedMinor: Int64
}

extension ReduceSnapshot {
    func toView() -> ReduceView {
        let vape = plan.productType == .vape
        let limit = max(dailyLimit, 1)
        let today = max(todayUnits, 0)
        let tone: ReduceTone = if today == 0 {
            .empty
        } else if today < limit {
            .under
        } else if today == limit {
            .at
        } else {
            .over
        }
        let over = max(today - limit, 0)
        let baselineUnits = plan.baselineUnitsPerDay
        return ReduceView(
            tone: tone,
            todayUnits: Int(today),
            limit: Int(limit),
            progressPermille: Int(min(today, limit) * permille / limit),
            overflowPermille: Int(min(over * permille / limit, permille)),
            overBy: Int(over),
            remaining: Int(max(limit - today, 0)),
            showNoneToday: !todayHasEntry,
            belowBaseline: tone == .over && !vape && baselineUnits > today ? Int(baselineUnits - today) : nil,
            bars: last7Days.map { ReduceBar(epochDay: $0.epochDay, units: $0.units) },
            baseline: vape ? nil : Int(baselineUnits),
            weekReductionUnits: vape ? nil : weekReductionUnits,
            weekSavedMinor: weekSavedMinor
        )
    }
}
