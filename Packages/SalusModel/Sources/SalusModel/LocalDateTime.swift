// The Swift stand-in for `kotlinx.datetime.LocalDateTime` — a wall-clock reading with no zone
// attached — plus the two conversions Android gets for free around it: `Instant.toLocalDateTime(zone)`
// and the pattern formatting of `java.time.format.DateTimeFormatter`. The zone-ful direction,
// `LocalDateTime.toInstant(zone)`, lives in `SalusCommon` because it needs the `Calendar` carve-out.
//
// Why the type exists. Android passes wall-clock readings around as `LocalDateTime`
// (`VitalsUiState.kt:20`, `AppointmentUiState.kt`), and `CLAUDE.md` had nothing in between its two
// poles: days are `LocalDate` / `epochDay`, instants are `Date`. So the pair is spelled out here, as
// a day plus the minute of day the rest of the port already stores times in (`SalusClock.swift:8-12`).
//
// It arrived feature-local in `FeatureVitals` (iOS-M2) with a note saying it moves here the moment a
// second feature needs it. iOS-M4's Appointments feature is that second consumer, so it moved.
//
// Why no `Calendar` appears, in any of the directions below:
//
//   * instant → wall clock is `epochMs + the zone's offset at that instant`, then integer division
//     into days and minutes. That is the arithmetic the M2 ruling names, and the same shape
//     `SalusClock.instant(of:minuteOfDay:)`'s own fallback uses. The zone lookup is
//     `TimeZone.secondsFromGMT(for:)`, which is not a calendar.
//   * wall clock → ISO text is decimal digits over the components, and back again through
//     `LocalDate(year:month:day:)` — the same proleptic Gregorian arithmetic both platforms run.
//   * wall clock → pattern text goes through `DateFormatter` with its zone pinned to GMT, fed the
//     instant that has those components *in GMT*. The formatter renders the components it is given,
//     so the device's region cannot move the day, and `CLAUDE.md`'s "never `Calendar` for a day"
//     holds literally — no `Calendar` value is constructed in this package at all. The locale stays
//     `Locale.current`, which is what Android's `Locale.getDefault()` is.
//
// Foundation is imported here, which no other file in `SalusModel` needs. That is within the layer
// rule — what `CLAUDE.md` bans from this package is a *UI* framework (SwiftUI/UIKit/AppKit/WatchKit),
// and `SalusCommon`, the other pure-domain package, has imported Foundation since iOS-M1. `Date`,
// `TimeZone` and `Locale` are the port's twins of `kotlinx.datetime.Instant`/`TimeZone` and
// `java.util.Locale`; there is no Foundation-free way to say "the offset this zone had at this
// instant".

import Foundation

/// A calendar day plus a minute of day: the twin of `kotlinx.datetime.LocalDateTime`
/// (`VitalsUiState.kt:20`).
public struct LocalDateTime: Equatable, Hashable, Sendable {
    public let date: LocalDate
    /// Minutes since local midnight, `0 ..< 1440`.
    public let minuteOfDay: Int

    /// - Precondition: `minuteOfDay` is in `0 ..< 1440`.
    ///
    /// A precondition rather than a failable initialiser: every value that reaches here comes from a
    /// time field, from `Date.wallClock(in:)` (which floors into range by construction) or from a
    /// literal, so an out-of-range minute is a programmer error, not input to validate. Making the
    /// initialiser failable would put a `try`/`guard` in front of every wall clock the port builds
    /// — the same reasoning `LocalDate(year:month:day:)` records for staying non-throwing. Left
    /// unchecked, `minuteOfDay = 1440` would serialise as `"…T24:00"`, which `isoLocalString`'s own
    /// parser rejects: the type would write text it cannot read back.
    public init(date: LocalDate, minuteOfDay: Int) {
        precondition(
            (0 ..< 1440).contains(minuteOfDay),
            "minuteOfDay must be in 0 ..< 1440, was \(minuteOfDay)"
        )
        self.date = date
        self.minuteOfDay = minuteOfDay
    }
}

extension Date {
    /// The wall clock this instant reads as in `zone` — the twin of
    /// `Instant.toLocalDateTime(zone)` (`VitalsViewModel.kt:127`, `WeightEditorViewModel.kt:42`).
    public func wallClock(in zone: TimeZone) -> LocalDateTime {
        let localMillis = epochMillisecondsForWallClock + Int64(zone.secondsFromGMT(for: self)) * 1000
        let (epochDay, millisOfDay) = Self.flooredDivision(localMillis, by: millisecondsPerDay)
        return LocalDateTime(
            date: LocalDate(epochDay: Int(epochDay)),
            minuteOfDay: Int(millisOfDay / 60000)
        )
    }

    /// The same conversion `SalusCommon`'s `Date.epochMilliseconds` performs
    /// (`SalusCommon/EpochMilliseconds.swift`), repeated here because `SalusModel` sits *below*
    /// `SalusCommon` and cannot reach it. It is deliberately `private` and writes no column, which
    /// is what leaves that file's "every writer of an epoch-millisecond column goes through one
    /// conversion" rule intact — the file header there names this twin from the other side.
    ///
    /// Keeping the two byte-identical still matters: a reading floored one millisecond apart lands
    /// on the previous minute at a boundary. `SalusCommonTests`'
    /// `WallClockEpochMillisecondsAgreementTests` fails if they ever drift.
    private var epochMillisecondsForWallClock: Int64 {
        let microseconds = (timeIntervalSince1970 * 1_000_000).rounded()
        return Int64((microseconds / 1000).rounded(.down))
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

/// GMT, spelled the long way. `TimeZone.gmt` carries a macOS 13 floor, and `SalusModel` declares no
/// macOS platform at all — `CLAUDE.md` keeps the `.macOS(.v14)` test-host concession to the packages
/// that genuinely need it, and adding one here to reach a nicer spelling of a fixed zero offset is
/// exactly what that rule forbids. `secondsFromGMT: 0` is a valid zone on every platform.
private let gmtZone = TimeZone(secondsFromGMT: 0)

extension LocalDateTime {
    /// This wall clock rendered with `pattern`, in `locale`.
    ///
    /// The twin of `DateTimeFormatter.ofPattern(pattern, locale).format(localDateTime)`
    /// (`VitalsScreen.kt:293`). The pattern is fixed rather than templated, exactly as Android's
    /// is: `setLocalizedDateFormatFromTemplate` would reorder the components per region, which
    /// Android does not do and which would make the two platforms draw different rows.
    public func formatted(pattern: String, locale: Locale = .current) -> String {
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
        formatter.timeZone = gmtZone
        formatter.dateFormat = pattern
        return formatter
    }
}

// MARK: - ISO-8601 local date-time

// The wire form of a wall-clock reading, and the one place the port has to agree with Kotlin
// character for character: `starts_at_local` is written by whichever platform saved the row and
// read by the other (`CLAUDE.md`, wall-clock semantics).
//
// `kotlinx.datetime.LocalDateTime.toString()` writes `yyyy-MM-dd'T'HH:mm`, appending `:ss` only
// when the seconds are non-zero; `LocalDateTime.parse` accepts either. This type has no seconds
// field — every time the app stores is a minute of day — so the writer never emits `:ss` and the
// reader accepts and discards it. Neither direction accepts a UTC offset or a `Z`: the value is a
// *local* date-time, and the zone travels beside it in `tz_id`.

extension LocalDateTime {
    /// This wall clock as `yyyy-MM-dd'T'HH:mm` — the twin of `LocalDateTime.toString()`.
    ///
    /// Years outside `-9999 ... 9999` are not representable in this format and are not reachable
    /// from any date the app stores; the year is padded to four digits and signed, nothing more.
    public var isoLocalString: String {
        let year = date.year < 0
            ? "-" + Self.padded(-date.year, to: 4)
            : Self.padded(date.year, to: 4)
        return "\(year)-\(Self.padded(date.month, to: 2))-\(Self.padded(date.day, to: 2))"
            + "T\(Self.padded(minuteOfDay / 60, to: 2)):\(Self.padded(minuteOfDay % 60, to: 2))"
    }

    /// The wall clock `isoLocalString` names, or `nil` if the text is not one — the twin of
    /// `LocalDateTime.parse`.
    ///
    /// Rejects anything Kotlin's parser rejects: an out-of-range component, an offset (`+03:00`),
    /// a `Z`, a fractional second, or trailing text. Accepts a `:ss` field and drops it, which is
    /// the only lossy step and only ever reachable from a writer that has seconds this type does not.
    public init?(isoLocalString text: String) {
        let halves = text.split(separator: "T", maxSplits: 1, omittingEmptySubsequences: false)
        guard halves.count == 2,
              let date = Self.parseDate(halves[0]),
              let minuteOfDay = Self.parseMinuteOfDay(halves[1])
        else { return nil }
        self.init(date: date, minuteOfDay: minuteOfDay)
    }

    private static func parseDate(_ text: Substring) -> LocalDate? {
        let negativeYear = text.hasPrefix("-")
        let fields = (negativeYear ? text.dropFirst() : text).split(separator: "-", omittingEmptySubsequences: false)
        guard fields.count == 3,
              let magnitude = digits(fields[0], count: 4),
              let month = digits(fields[1], count: 2),
              let day = digits(fields[2], count: 2)
        else { return nil }

        let year = negativeYear ? -magnitude : magnitude
        let date = LocalDate(year: year, month: month, day: day)
        // `LocalDate(year:month:day:)` normalises an out-of-range component (2026-02-31 becomes
        // 2026-03-03); `LocalDateTime.parse` rejects it. Reject what did not survive the trip.
        guard date.year == year, date.month == month, date.day == day else { return nil }
        return date
    }

    private static func parseMinuteOfDay(_ text: Substring) -> Int? {
        let fields = text.split(separator: ":", omittingEmptySubsequences: false)
        guard fields.count == 2 || fields.count == 3,
              let hour = digits(fields[0], count: 2), hour < 24,
              let minute = digits(fields[1], count: 2), minute < 60
        else { return nil }
        if fields.count == 3 {
            guard let second = digits(fields[2], count: 2), second < 60 else { return nil }
        }
        return hour * 60 + minute
    }

    /// `text` read as exactly `count` ASCII decimal digits. `Int(_:)` alone would accept a sign, a
    /// shorter field, and non-ASCII digits — none of which ISO-8601 allows in a fixed-width field.
    private static func digits(_ text: Substring, count: Int) -> Int? {
        guard text.count == count, text.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(text)
    }

    private static func padded(_ value: Int, to width: Int) -> String {
        String(repeating: "0", count: max(0, width - String(value).count)) + String(value)
    }
}

extension LocalDate {
    /// This day rendered with `pattern` — the day-only form of the above
    /// (`VitalsViewModel.kt:231-234`, `EditorDateField.kt:35, 42`).
    public func formatted(pattern: String, locale: Locale = .current) -> String {
        LocalDateTime(date: self, minuteOfDay: 0).formatted(pattern: pattern, locale: locale)
    }
}
