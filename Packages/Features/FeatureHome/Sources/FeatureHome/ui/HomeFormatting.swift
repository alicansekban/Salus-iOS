// The four things the dashboard formats, ported from the private helpers at the bottom of
// `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/ui/HomeScreen.kt` plus the two
// `DateTimeFormatter`s its cards build inline (`HomeScreen.kt:151-154`, `:279-281`, `:429-436`).
//
// Kotlin keeps them file-private next to the composables; Swift has no per-file privacy for
// something four `View` files call, so they sit in one internal namespace instead. Nothing outside
// this package can name it — the package exports `HomeRoute` and nothing else.
//
// THE LOCALE ASYMMETRY IS ANDROID'S AND IS PORTED AS-IS (research §9, row 14): `minutes` formats in
// the **view's** locale (`HomeScreen.kt:430` takes `locale`), `number` in a fixed root locale
// (`HomeScreen.kt:433` names `Locale.ROOT`), so a Turkish device reads "08:00" alongside "72.5" and
// not "72,5". Unifying the two would be a copy change, not a port.
//
// NO `Calendar` ANYWHERE HERE, and two of the four helpers are the reason the rule needs stating:
//
//   `fullDate` is a **day**, so it goes through `SalusModel.LocalDate(epochDay:)` and its
//   `formatted(pattern:locale:)`, which renders through a fixed-GMT `DateFormatter` over six
//   numbers. Android's `DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL)` has no
//   `DateFormatter.dateFormat` twin that takes a *style* without a `Date`, so the locale's FULL
//   pattern is derived once from a template and handed to that renderer.
//
//   `appointmentStart` is an **instant** (`epochMs` + the zone it was made in), which is the one
//   thing `Foundation.Date` is still for in this port. It formats with `Date.FormatStyle`, whose
//   `.timeZone(_:)` is Android's `atZone(ZoneId.of(id))` and whose `?? .current` is the
//   `runCatching { … }.getOrDefault(ZoneId.systemDefault())` around it (`HomeScreen.kt:296-297`).

import Foundation
import SalusModel

/// The dashboard's formatters (`HomeScreen.kt:429-436` plus the two inline `DateTimeFormatter`s).
enum HomeFormatting {
    /// `SparklineWidth = 96.dp` (`HomeScreen.kt:435`).
    static let sparklineWidth: CGFloat = 96
    /// `SparklineHeight = 32.dp` (`HomeScreen.kt:436`).
    static let sparklineHeight: CGFloat = 32

    /// `formatMinutes(minutes, locale)` (`HomeScreen.kt:429-430`).
    ///
    /// `%02lld` rather than Kotlin's `%02d`: `String(format:)` reads a 32-bit `CInt` for `%d`, and
    /// Swift's `Int` is encoded 64-bit in the argument list — the same remapping the string catalog
    /// makes for `%1$d` (see `HomeStrings.swift`). The rendered digits are identical.
    static func minutes(_ minuteOfDay: Int, locale: Locale) -> String {
        String(format: "%02lld:%02lld", locale: locale, minuteOfDay / 60, minuteOfDay % 60)
    }

    /// `formatNumber(value)` (`HomeScreen.kt:432-433`) — an integer when the value is whole, one
    /// decimal otherwise, always with a `.` separator.
    ///
    /// The whole-number arm renders `%.0f` where Kotlin writes `value.toInt().toString()`: for a
    /// whole `Double` the two print the same digits, and `Int(value)` traps on a value outside
    /// `Int`'s range, which is a crash a formatter should not be able to cause.
    static func number(_ value: Double) -> String {
        // `Locale.ROOT` (`HomeScreen.kt:433`). `en_US_POSIX` is the fixed, region-independent
        // locale Foundation offers for exactly this — a `.` separator that no device setting moves.
        let root = Locale(identifier: "en_US_POSIX")
        let isWhole = value.truncatingRemainder(dividingBy: 1) == 0
        return String(format: isWhole ? "%.0f" : "%.1f", locale: root, value)
    }

    /// The header's date: `DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL)` over
    /// `LocalDate.ofEpochDay(todayEpochDay)` (`HomeScreen.kt:151-154`, `:170-172`).
    ///
    /// Two steps, because Foundation splits what `java.time` joins: `DateFormatter.dateFormat(
    /// fromTemplate:options:locale:)` answers how *this* locale orders a weekday, day, month and
    /// year — the FULL style's field set — and `LocalDate.formatted(pattern:locale:)` renders the
    /// day with it. The template's fallback is the Turkish/English order, since Turkish is both the
    /// default and the fallback locale (spec §6.4); it is unreachable for every locale Foundation
    /// ships and exists only because the API is optional.
    static func fullDate(epochDay: Int, locale: Locale) -> String {
        let pattern = DateFormatter.dateFormat(
            fromTemplate: "EEEEdMMMMyyyy",
            options: 0,
            locale: locale
        ) ?? "d MMMM yyyy EEEE"
        return LocalDate(epochDay: epochDay).formatted(pattern: pattern, locale: locale)
    }

    /// One appointment's start: `Instant.ofEpochMilli(...).atZone(...).format(
    /// ofLocalizedDateTime(MEDIUM, SHORT))` (`HomeScreen.kt:279-281`, `:294-299`).
    ///
    /// `.abbreviated` is Java's `MEDIUM` date and `.shortened` its `SHORT` time. An unparsable
    /// `timeZoneId` falls back to the device zone, which is `runCatching { ZoneId.of(id) }
    /// .getOrDefault(ZoneId.systemDefault())` (`HomeScreen.kt:296-297`) one for one.
    static func appointmentStart(epochMs: Int64, timeZoneId: String, locale: Locale) -> String {
        let instant = Date(timeIntervalSince1970: Double(epochMs) / 1000)
        // Set on the style rather than through `.timeZone(_:)`, which is the *symbol* modifier
        // (it adds a zone field to the output) and not the zone the fields are read in.
        let style = Date.FormatStyle(
            date: .abbreviated,
            time: .shortened,
            locale: locale,
            timeZone: TimeZone(identifier: timeZoneId) ?? .current
        )
        return instant.formatted(style)
    }
}
