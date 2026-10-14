// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// GoalCardState.kt`.
//
// Which savings-goal card the main screen draws, decided from the state alone, so the rules (a free
// account sees the lock whatever is stored, a stamped goal stays reached) are plain logic and not
// view code.

import SalusSmoking

private let msPerDay: Int64 = 24 * 60 * 60 * 1000
private let daysPerWeek: Int64 = 7

enum GoalCardState: Equatable, Sendable {
    /// No premium: the card sells the feature, and the stored goal, if any, is kept but hidden.
    case locked
    /// Premium, no goal yet.
    case none
    case inProgress(GoalInProgress)
    case reached(title: String, targetMinor: Int64)
}

/// A goal still being saved for. `etaDays` is `nil` while there is no daily rate to extrapolate from.
struct GoalInProgress: Equatable, Sendable {
    let title: String
    let savedMinor: Int64
    let targetMinor: Int64
    let permille: Int
    let etaDays: Int64?
}

extension SmokingMainUiState {
    /// The card for ``snapshot``, or `nil` while there is no plan to save for.
    func goalCard() -> GoalCardState? {
        guard let snapshot, snapshot.hasPlan else { return nil }
        guard isPremium else { return .locked }
        guard let progress = snapshot.goalProgress else { return GoalCardState.none }
        let goal = progress.goal
        if progress.reached {
            return .reached(title: goal.title, targetMinor: goal.targetMinor)
        }
        return .inProgress(
            GoalInProgress(
                title: goal.title,
                savedMinor: progress.savedTowardMinor,
                targetMinor: goal.targetMinor,
                permille: progress.permille,
                etaDays: goalEtaDays(
                    remainingMinor: goal.targetMinor - progress.savedTowardMinor,
                    dailyRateMinor: snapshot.dailyRateMinor
                )
            )
        )
    }
}

extension SmokingSnapshot {
    /// The active goal, whichever mode the snapshot is in.
    var goalProgress: GoalProgress? {
        switch self {
        case let .quit(quit): quit.goal
        case let .reduce(reduce): reduce.goal
        case .notSetUp: nil
        }
    }

    /// The plan's currency, which the goal sheet types its target in; `nil` before there is a plan.
    var currencyCode: String? {
        switch self {
        case let .quit(quit): quit.plan.currencyCode
        case let .reduce(reduce): reduce.plan.currencyCode
        case .notSetUp: nil
        }
    }

    /// Whether there is a plan to save under: the goal card exists in QUIT and in REDUCE alike.
    var hasPlan: Bool {
        if case .notSetUp = self {
            false
        } else {
            true
        }
    }

    /// How much the person saves in a day at the moment, in minor units: a QUIT attempt's average
    /// over its own length, a REDUCE week's saving over seven days. Integer arithmetic only. The
    /// QUIT product stays far inside an `Int64` (20 years at 60 a day at 10 000 minor is about
    /// 4e9, times 8.64e7).
    fileprivate var dailyRateMinor: Int64 {
        switch self {
        case let .quit(quit): quit.attemptElapsedMs > 0 ? quit.savedMinor * msPerDay / quit.attemptElapsedMs : 0
        case let .reduce(reduce): reduce.weekSavedMinor / daysPerWeek
        case .notSetUp: 0
        }
    }
}

/// Whole days to cover `remainingMinor` at `dailyRateMinor`, rounded up; `nil` without a positive rate.
func goalEtaDays(remainingMinor: Int64, dailyRateMinor: Int64) -> Int64? {
    guard dailyRateMinor > 0, remainingMinor > 0 else { return nil }
    return (remainingMinor + dailyRateMinor - 1) / dailyRateMinor
}
