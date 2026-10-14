// Twin of `core/smoking/.../stats/StageTimeLeft.kt` (contract §8.15): the one "time left to the next
// stage" rounding that Home, the Main stage card and the timeline rows share, so one snapshot reads
// the same figure on every surface.

/// The unit a "time left to the next stage" label is written in.
public enum TimeLeftUnit: Sendable, Equatable {
    case minutes
    case hours
    case days
}

/// A rounded-up time left: `count` of `unit`, never below 1.
public struct TimeLeft: Sendable, Equatable {
    public let unit: TimeLeftUnit
    public let count: Int

    public init(unit: TimeLeftUnit, count: Int) {
        self.unit = unit
        self.count = count
    }
}

public enum StageTimeLeft {
    private static let msPerMinute: Int64 = 60000
    private static let msPerHour: Int64 = 3_600_000
    private static let msPerDay: Int64 = 86_400_000
    private static let minutesPerHour = 60
    private static let hoursPerDay = 24

    /// The count is rounded **up** first and the unit follows the rounded count: under 60 minutes
    /// is minutes, under 24 hours is hours, anything more is days. So 59 min 30 s reads "1 hour" and
    /// 23 h 59 min reads "1 day", never "60 minutes" or "24 hours". "3 days left" never promises
    /// the stage sooner than it comes, and it is at least one minute, so a stage seconds away (or a
    /// clock set behind the start) does not say zero.
    public static func of(remainingMs: Int64) -> TimeLeft {
        let minutes = max(1, ceilDiv(remainingMs, msPerMinute))
        if minutes < minutesPerHour {
            return TimeLeft(unit: .minutes, count: minutes)
        }
        let hours = ceilDiv(remainingMs, msPerHour)
        if hours < hoursPerDay {
            return TimeLeft(unit: .hours, count: hours)
        }
        return TimeLeft(unit: .days, count: ceilDiv(remainingMs, msPerDay))
    }

    /// Quotient and remainder rather than `(value + divisor - 1) / divisor`, which overflows for a
    /// value near `Int64.max`.
    private static func ceilDiv(_ value: Int64, _ divisor: Int64) -> Int {
        guard value > 0 else { return 0 }
        return Int(value / divisor + (value % divisor == 0 ? 0 : 1))
    }
}
