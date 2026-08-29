// No Android twin, and that is the point: Kotlin walks `DayOfWeek.entries` and asks each entry for
// its `TextStyle.NARROW` display name, which is Monday-first by definition of the enum
// (`CycleScreen.kt:186-203`). Foundation has no `DayOfWeek`, so the narrow letters have to come
// from a `Calendar`, which is Sunday-first and carries a locale.
//
// **This file is the one place in the tree a `Calendar` is read for a localized symbol**, and
// `CLAUDE.md`'s `LocalDate` rule names it as such. Two properties make it safe to be that place:
//
//   * the calendar is a fixed `Calendar(identifier: .gregorian)` with the *caller's* locale set,
//     never `Calendar.current` — which follows the device's region and would answer a Hijri or
//     Buddhist week for a device configured that way;
//   * no `Date` is ever built, read or shifted here. The symbols are a static table on the
//     calendar; nothing in this file computes, compares or converts a day. Day arithmetic remains
//     `SalusModel.LocalDate` / `epochDay` integer math, and the instant↔day boundary remains
//     `SalusCommon/SalusClock.swift` plus `SalusReminder`'s notification gateway.
//
// A caller passes the locale it draws in — a SwiftUI view reads `@Environment(\.locale)`, which is
// the resolved locale of the view hierarchy and the same one every other localized string in that
// view resolves against.

import Foundation

/// The localized weekday letters a calendar grid heads its columns with.
public enum SalusWeekdaySymbols {
    /// Days in a week; the length of every array this type answers with.
    private static let daysPerWeek = 7

    /// The seven narrow standalone weekday letters in `locale`, rotated so Monday comes first.
    ///
    /// "Standalone" is the form a label uses on its own, outside a sentence — the twin of Kotlin's
    /// `TextStyle.NARROW` on `DayOfWeek`, which is also a standalone name. Foundation orders its
    /// symbol arrays by Gregorian weekday number, so index 0 is Sunday; the grid starts on Monday
    /// on both platforms, so Sunday moves to the end.
    ///
    /// - Parameter locale: the locale to name the days in — a view passes its
    ///   `@Environment(\.locale)`.
    /// - Returns: seven letters, Monday first. Only the calendar's own array is ever returned
    ///   unrotated, and only if Foundation were to answer with something other than seven symbols.
    public static func narrowMondayFirst(locale: Locale) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == daysPerWeek else { return symbols }
        return Array(symbols.dropFirst()) + symbols.prefix(1)
    }
}
