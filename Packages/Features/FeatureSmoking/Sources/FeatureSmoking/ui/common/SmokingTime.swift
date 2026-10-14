// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/common/
// SmokingTime.kt`.
//
// Formatting an instant for a screen. The zone is always passed in (the clock's, never the device
// default read here), so a preview and a test show the same text anywhere. A *day* here is the
// `epochDay` `SalusCommon` answers; nothing in this file builds a `Calendar`.

import Foundation
import SalusCommon
import SalusModel

/// The local calendar day `epochMs` falls on in `zone`, as an `epochDay`.
func localEpochDay(of epochMs: Int64, in zone: TimeZone) -> Int64 {
    epochDay(of: epochMs, in: zone)
}

/// Minutes since local midnight of `epochMs` in `zone`.
func localMinuteOfDay(of epochMs: Int64, in zone: TimeZone) -> Int {
    Date(epochMilliseconds: epochMs).wallClock(in: zone).minuteOfDay
}

/// The instant of `minuteOfDay` on `epochDay` in `zone`, in epoch milliseconds; a daylight-saving
/// gap resolves forward.
func instantMs(epochDay: Int64, minuteOfDay: Int, zone: TimeZone) -> Int64 {
    LocalDateTime(date: LocalDate(epochDay: Int(epochDay)), minuteOfDay: minuteOfDay)
        .instant(in: zone)
        .epochMilliseconds
}

/// "14:30" in the locale's own clock style (`FormatStyle.SHORT`).
func formatClockTime(epochMs: Int64, zone: TimeZone, locale: Locale) -> String {
    // Set on the style rather than through `.timeZone(_:)`, which is the *symbol* modifier (it adds
    // a zone field to the output) and not the zone the fields are read in.
    let style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: zone)
    return Date(epochMilliseconds: epochMs).formatted(style)
}

/// "8 Mart 2026, 09:30" — the day and the time of an instant that is not today. The day pattern is
/// fixed, as Android's is, so the two platforms draw the same row in every locale.
func formatDateTime(epochMs: Int64, zone: TimeZone, locale: Locale) -> String {
    let day = Date(epochMilliseconds: epochMs).wallClock(in: zone).formatted(pattern: "d MMMM yyyy", locale: locale)
    return "\(day), \(formatClockTime(epochMs: epochMs, zone: zone, locale: locale))"
}
