// Ported from `remainingLabel` in `feature/smoking/.../ui/timeline/SmokingTimelineScreen.kt`, which
// the main screen's next-stage card shares: "n gün kaldı" at the largest unit that fits.

/// How much of a stage is left, cut at the largest unit that fits. The unit decides which sentence
/// the screen speaks, so the choice lives here rather than in a view.
enum StageRemaining: Equatable {
    case days(Int64)
    case hours(Int)
    case minutes(Int)

    /// Under a minute (or a clock set behind the start) still reads one minute: zero minutes left
    /// on a stage that has not unlocked looks like a bug.
    init(remainingMs: Int64) {
        switch timeLabelOf(remainingMs) {
        case let .days(days, _, _): self = .days(days)
        case let .hours(hours, _): self = .hours(hours)
        case let .minSec(minutes, _): self = .minutes(max(1, minutes))
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
