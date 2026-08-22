// Ported 1:1 from Android
// `core/model/src/main/kotlin/com/alicansekban/salus/core/model/RecurrenceRule.kt`.

/// PURE SWIFT. Single source of truth for "does a schedule occur on this day" — shared by the
/// medications feature (dose occurrence generation) and the Today dashboard. Day arithmetic
/// runs on epochDay ints; epochDay 0 = 1970-01-01, a Thursday.
public enum RecurrenceRule {
    /// 1970-01-01 is a Thursday; Monday-based index (Monday = 0) of epochDay 0 is 3.
    private static let epochDayZeroMondayIndex = 3

    /// - Parameters:
    ///   - daysOfWeekMask: bit 0 = Monday .. bit 6 = Sunday; only meaningful for `daysOfWeek`.
    public static func occursOn(
        recurrence: Recurrence,
        daysOfWeekMask: Int,
        intervalDays: Int?,
        anchorEpochDay: Int,
        epochDay: Int
    ) -> Bool {
        if epochDay < anchorEpochDay {
            return false
        }
        switch recurrence {
        case .daily:
            return true

        case .daysOfWeek:
            // Kotlin's `.mod(7)` is non-negative; `flooredMod` is its twin (see `LocalDate.swift`).
            let mondayBasedIndex = (epochDay + epochDayZeroMondayIndex).flooredMod(7)
            return daysOfWeekMask & (1 << mondayBasedIndex) != 0

        case .intervalDays:
            guard let interval = intervalDays else { return false }
            // Kotlin writes `(epochDay - anchorEpochDay) % interval == 0`; `isMultiple(of:)` is
            // the same test, and the `interval > 0` guard short-circuits before it either way.
            return interval > 0 && (epochDay - anchorEpochDay).isMultiple(of: interval)

        case .asNeeded:
            return false
        }
    }
}
