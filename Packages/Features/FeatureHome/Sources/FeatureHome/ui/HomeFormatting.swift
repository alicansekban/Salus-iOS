// The four things the dashboard formats, ported from the private helpers at the bottom of
// `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/ui/HomePager.kt:376-380` plus
// the three `DateTimeFormatter`s the hero and the appointment card build
// (`HomeScreen.kt:194-196`, `HomeCards.kt:242-246`).
//
// Kotlin keeps them file-private next to the composables; Swift has no per-file privacy for
// something four `View` files call, so they sit in one internal namespace instead. Nothing outside
// this package can name it — the package exports `HomeRoute` and nothing else.
//
// THE LOCALE ASYMMETRY IS ANDROID'S AND IS PORTED AS-IS (research §9, row 14): `minutes` formats in
// the **view's** locale (`HomePager.kt:377` takes `locale`), `number` in a fixed root locale
// (`HomePager.kt:380` names `Locale.ROOT`), so a Turkish device reads "08:00" alongside "72.5" and
// not "72,5". Unifying the two would be a copy change, not a port.
//
// M15 SHORTENED THE HERO'S DATE from `FormatStyle.FULL` to `FormatStyle.MEDIUM`
// (`HomeScreen.kt:195`): the band's overline is a small line beside a chip, and a spelled-out
// weekday wrapped it. `todayDate` follows, and is the reason the helper is no longer `fullDate`.
//
// NO `Calendar` ANYWHERE HERE, and two of the four helpers are the reason the rule needs stating:
//
//   `todayDate` is a **day**, so it goes through `SalusModel.LocalDate(epochDay:)` and its
//   `formatted(pattern:locale:)`, which renders through a fixed-GMT `DateFormatter` over six
//   numbers. Android's `DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)` has no
//   `DateFormatter.dateFormat` twin that takes a *style* without a `Date`, so the locale's MEDIUM
//   pattern is derived once from a template and handed to that renderer.
//
//   `appointmentDate` / `appointmentTime` read an **instant** (`epochMs` + the zone it was made
//   in), which is the one thing `Foundation.Date` is still for in this port. They format with
//   `Date.FormatStyle`, whose `timeZone:` is Android's `atZone(ZoneId.of(id))` and whose
//   `?? .current` is the `runCatching { … }.getOrDefault(ZoneId.systemDefault())` around it
//   (`HomeCards.kt:159`).

import Foundation
import SalusModel

/// The dashboard's formatters (`HomePager.kt:376-380` plus `HomeCards.kt:242-246`).
enum HomeFormatting {
    /// `formatMinutes(minutes, locale)` (`HomePager.kt:376-377`).
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

    /// The hero band's date: `DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)` over
    /// `LocalDate.ofEpochDay(todayEpochDay)` (`HomeScreen.kt:194-199`).
    ///
    /// Two steps, because Foundation splits what `java.time` joins: `DateFormatter.dateFormat(
    /// fromTemplate:options:locale:)` answers how *this* locale orders a day, an abbreviated month
    /// and a year — the MEDIUM style's field set — and `LocalDate.formatted(pattern:locale:)`
    /// renders the day with it. The template's fallback is the Turkish/English order, since Turkish
    /// is both the default and the fallback locale (spec §6.4); it is unreachable for every locale
    /// Foundation ships and exists only because the API is optional.
    static func todayDate(epochDay: Int, locale: Locale) -> String {
        let pattern = DateFormatter.dateFormat(
            fromTemplate: "dMMMyyyy",
            options: 0,
            locale: locale
        ) ?? "d MMM yyyy"
        return LocalDate(epochDay: epochDay).formatted(pattern: pattern, locale: locale)
    }

    /// One appointment's day: `Instant.ofEpochMilli(...).atZone(...).format(
    /// ofLocalizedDate(MEDIUM))` (`HomeCards.kt:159-160`, `:242-243`).
    ///
    /// M15 split what used to be one line into a date under the title and a time in the trailing
    /// chip (`HomeCards.kt:184-193`), so the single `MEDIUM, SHORT` formatter became these two.
    /// `.abbreviated` is Java's `MEDIUM`.
    static func appointmentDate(epochMs: Int64, timeZoneId: String, locale: Locale) -> String {
        formatted(epochMs: epochMs, timeZoneId: timeZoneId, locale: locale, date: .abbreviated, time: .omitted)
    }

    /// One appointment's clock time: `...format(ofLocalizedTime(SHORT))` (`HomeCards.kt:245-246`).
    /// `.shortened` is Java's `SHORT`.
    static func appointmentTime(epochMs: Int64, timeZoneId: String, locale: Locale) -> String {
        formatted(epochMs: epochMs, timeZoneId: timeZoneId, locale: locale, date: .omitted, time: .shortened)
    }

    /// The shared half of the two above. An unparsable `timeZoneId` falls back to the device zone,
    /// which is `runCatching { ZoneId.of(id) }.getOrDefault(ZoneId.systemDefault())`
    /// (`HomeCards.kt:159`) one for one.
    private static func formatted(
        epochMs: Int64,
        timeZoneId: String,
        locale: Locale,
        date: Date.FormatStyle.DateStyle,
        time: Date.FormatStyle.TimeStyle
    ) -> String {
        let instant = Date(timeIntervalSince1970: Double(epochMs) / 1000)
        // Set on the style rather than through `.timeZone(_:)`, which is the *symbol* modifier
        // (it adds a zone field to the output) and not the zone the fields are read in.
        let style = Date.FormatStyle(
            date: date,
            time: time,
            locale: locale,
            timeZone: TimeZone(identifier: timeZoneId) ?? .current
        )
        return instant.formatted(style)
    }
}
