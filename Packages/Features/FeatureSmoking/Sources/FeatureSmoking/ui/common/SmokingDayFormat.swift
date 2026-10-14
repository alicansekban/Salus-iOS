// Ported from the date helpers at the foot of `SmokingHistoryScreen.kt` (`formatDay`, `dayHeader`).
//
// The patterns are fixed, as Android's are, so the two platforms draw the same row in every locale.
// The zone is always passed in and a *day* is an `epochDay`; nothing here builds a `Calendar`.

import Foundation
import SalusCommon
import SalusModel

/// "10 Mar 2026" — the day an instant falls on in `zone`, for an attempt's span.
func formatShortDay(epochMs: Int64, zone: TimeZone, locale: Locale) -> String {
    Date(epochMilliseconds: epochMs).wallClock(in: zone).formatted(pattern: "d MMM yyyy", locale: locale)
}

/// The log's day header: "Bugün", "Dün", else "8 Mart 2026".
func formatDayHeader(epochDay: Int64, todayEpochDay: Int64, locale: Locale) -> String {
    switch epochDay {
    case todayEpochDay: SmokingStrings.historyDayToday
    case todayEpochDay - 1: SmokingStrings.historyDayYesterday
    default: LocalDate(epochDay: Int(epochDay)).formatted(pattern: "d MMMM yyyy", locale: locale)
    }
}
