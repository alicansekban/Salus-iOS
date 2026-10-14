// Twin of `feature/smoking/.../ui/main/StageTimeLeftText.kt`: "n gün kaldı" for the time left to a
// health stage, on the rounding every surface shares (`SalusSmoking.StageTimeLeft`, contract
// section 8.15). Main's stage card, the timeline rows and the stage sheet all read this one type.

import SalusSmoking

/// How much of a stage is left: a count rounded up and never below one minute, in the unit that
/// follows the rounded count ("1 saat", not "60 dk"; "1 gün", not "24 saat"). The unit decides which
/// sentence the screen speaks, so the choice lives here rather than in a view.
enum StageRemaining: Equatable {
    case days(Int)
    case hours(Int)
    case minutes(Int)

    init(remainingMs: Int64) {
        let left = StageTimeLeft.of(remainingMs: remainingMs)
        switch left.unit {
        case .days: self = .days(left.count)
        case .hours: self = .hours(left.count)
        case .minutes: self = .minutes(left.count)
        }
    }

    /// "11 gün kaldı", "3 saat kaldı", "7 dk kaldı".
    var text: String {
        switch self {
        case let .days(days): SmokingStrings.stageRemainingDays(days)
        case let .hours(hours): SmokingStrings.stageRemainingHours(hours)
        case let .minutes(minutes): SmokingStrings.stageRemainingMinutes(minutes)
        }
    }
}
