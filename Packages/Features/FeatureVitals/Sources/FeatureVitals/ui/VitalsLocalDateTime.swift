// No single Kotlin twin: this is what `kotlinx.datetime`'s `LocalDateTime` and
// `Instant.toLocalDateTime(zone)` become on iOS, plus the pattern formatting Android gets from
// `java.time.format.DateTimeFormatter`.
//
// Why the type exists. `VitalsListItem.measuredAt` is a `LocalDateTime` on Android
// (`VitalsUiState.kt:20`) — a wall-clock reading with no zone attached, which is what the list row
// draws. `CLAUDE.md` has no such type: days are `SalusModel.LocalDate` / `epochDay`, instants are
// `Date`, and there is deliberately nothing in between. So the pair is spelled out here, as a day
// plus the minute of day the rest of the port already stores times in (`SalusClock.swift:8-12`).
//
// Why no `Calendar` appears, in either direction:
//
//   * instant → wall clock is `epochMs + the zone's offset at that instant`, then integer division
//     into days and minutes. That is the arithmetic the M2 ruling names, and the same shape
//     `SalusClock.instant(of:minuteOfDay:)`'s own fallback uses. The zone lookup is
//     `TimeZone.secondsFromGMT(for:)`, which is not a calendar.
//   * wall clock → text goes through `DateFormatter` with its zone pinned to GMT, fed the instant
//     that has those components *in GMT*. The formatter renders the components it is given, so the
//     device's region cannot move the day, and `CLAUDE.md`'s "never `Calendar` for a day" holds
//     literally — no `Calendar` value is constructed in this feature at all. The locale stays
//     `Locale.current`, which is what Android's `Locale.getDefault()` is.

import Foundation
import SalusCommon
import SalusModel

/// A calendar day plus a minute of day: the feature-local twin of `kotlinx.datetime.LocalDateTime`
/// (`VitalsUiState.kt:20`).
///
/// Feature-local on purpose. The moment a second feature needs it, it moves to `SalusModel` beside
/// `LocalDate` rather than being copied.
public struct VitalsLocalDateTime: Equatable, Hashable, Sendable {
    public let date: LocalDate
    /// Minutes since local midnight, `0 ..< 1440`.
    public let minuteOfDay: Int

    public init(date: LocalDate, minuteOfDay: Int) {
        self.date = date
        self.minuteOfDay = minuteOfDay
    }
}

extension Date {
    /// The wall clock this instant reads as in `zone` — the twin of
    /// `Instant.toLocalDateTime(zone)` (`VitalsViewModel.kt:127`, `WeightEditorViewModel.kt:42`).
    func wallClock(in zone: TimeZone) -> VitalsLocalDateTime {
        let localMillis = epochMilliseconds + Int64(zone.secondsFromGMT(for: self)) * 1000
        let (epochDay, millisOfDay) = Self.flooredDivision(localMillis, by: millisecondsPerDay)
        return VitalsLocalDateTime(
            date: LocalDate(epochDay: Int(epochDay)),
            minuteOfDay: Int(millisOfDay / 60000)
        )
    }

    /// Euclidean division: `Int64`'s `/` truncates towards zero, which would put an instant before
    /// 1970 on the wrong day and give it a negative time of day.
    private static func flooredDivision(_ value: Int64, by divisor: Int64) -> (quotient: Int64, remainder: Int64) {
        var quotient = value / divisor
        var remainder = value % divisor
        if remainder < 0 {
            quotient -= 1
            remainder += divisor
        }
        return (quotient, remainder)
    }
}

private let millisecondsPerDay: Int64 = 86_400_000

extension VitalsLocalDateTime {
    /// This wall clock rendered with `pattern`, in `locale`.
    ///
    /// The twin of `DateTimeFormatter.ofPattern(pattern, locale).format(localDateTime)`
    /// (`VitalsScreen.kt:293`). The pattern is fixed rather than templated, exactly as Android's
    /// is: `setLocalizedDateFormatFromTemplate` would reorder the components per region, which
    /// Android does not do and which would make the two platforms draw different rows.
    func formatted(pattern: String, locale: Locale = .current) -> String {
        Self.formatter(pattern: pattern, locale: locale).string(from: gmtInstant)
    }

    /// The instant whose *GMT* components are this wall clock. Only the formatter above sees it —
    /// it is a carrier for six numbers, never a real point in time.
    private var gmtInstant: Date {
        Date(timeIntervalSince1970: Double(date.epochDay) * 86400 + Double(minuteOfDay) * 60)
    }

    /// A fresh formatter per call. `DateFormatter` is neither `Sendable` nor cheap to share, and
    /// the one hot caller — `ChartUiModel.xLabel`, a `@Sendable` closure — cannot capture one at
    /// all. Android caches with `remember(locale)`; here the cost is a few formatter allocations
    /// per redraw, which is below the noise floor of drawing the row itself.
    private static func formatter(pattern: String, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = .gmt
        formatter.dateFormat = pattern
        return formatter
    }
}

extension LocalDate {
    /// This day rendered with `pattern` — the day-only form of the above
    /// (`VitalsViewModel.kt:231-234`, `EditorDateField.kt:35, 42`).
    func formatted(pattern: String, locale: Locale = .current) -> String {
        VitalsLocalDateTime(date: self, minuteOfDay: 0).formatted(pattern: pattern, locale: locale)
    }
}
