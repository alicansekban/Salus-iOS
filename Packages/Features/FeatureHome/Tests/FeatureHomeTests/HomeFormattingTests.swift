import Foundation
import Testing

@testable import FeatureHome

/// The two private helpers at the bottom of `HomeScreen.kt` (`:429-433`), and the one thing about
/// them a reader gets wrong: **they do not use the same locale.**
///
/// `formatMinutes` formats in the composition locale, `formatNumber` in `Locale.ROOT`
/// (research §9, row 14), so a Turkish device reads "08:00" *and* "72.5" — a clock in its own
/// locale beside a number with a `.` separator no device setting can move. Ported as-is under plan
/// ruling 6, which makes this suite the pin: a later "let's unify the locales" arrives as a failing
/// test with the reason attached, rather than as a silent copy change.
///
/// No Kotlin test twin: `HomeScreen.kt`'s helpers are `private` and Compose screens carry no test
/// file, so every case here is iOS-only.
@Suite("Home formatting")
struct HomeFormattingTests {
    /// Turkish is the source language and its number separator is `,` — which is exactly what
    /// `formatNumber` must NOT produce, and what a naive `String(format:)` would.
    private static let turkish = Locale(identifier: "tr_TR")

    // MARK: - formatNumber (`HomeScreen.kt:432-433`)

    @Test(
        "a whole value loses its decimals and a fractional one keeps exactly one",
        arguments: [
            // Kotlin: `value.toInt().toString()`.
            (72.0, "72"),
            (0.0, "0"),
            (-3.0, "-3"),
            (120.0, "120"),
            // Kotlin: `String.format(Locale.ROOT, "%.1f", value)`.
            (72.5, "72.5"),
            (0.5, "0.5"),
            // `%.1f` rounds the *binary* value, which is what Java's `String.format` does too:
            // -3.25 is exact and rounds to even, 99.95 is stored a hair above and carries.
            (-3.25, "-3.2"),
            (99.95, "100.0")
        ]
    )
    func number(value: Double, expected: String) {
        #expect(HomeFormatting.number(value) == expected)
    }

    /// The separator is the whole point of `Locale.ROOT`: `HomeFormatting.number` takes no locale
    /// at all, so a Turkish *view* locale — the one the row beside it formats its clock in — cannot
    /// reach it. Asserted through the rendered text rather than by inspecting the helper, because
    /// the rendered text is what the divergence is about.
    @Test("the decimal separator is a dot whatever the view locale is")
    func numberIgnoresTheViewLocale() {
        // What a locale-sensitive format would produce for the same value, in the same process.
        #expect(String(format: "%.1f", locale: Self.turkish, 72.5) == "72,5")
        #expect(HomeFormatting.number(72.5) == "72.5")
    }

    /// A value past `Int`'s range still formats. Kotlin's `value.toInt()` saturates at
    /// `Int.MAX_VALUE`; Swift's `Int(value)` would **trap**, which is why the whole-number arm
    /// renders `%.0f` instead. No weight is ever this large — the point is that a formatter cannot
    /// be the thing that crashes the dashboard.
    @Test("a value beyond Int's range still formats instead of trapping")
    func hugeValue() {
        // 1e19 > Int64.max (≈9.22e18).
        #expect(HomeFormatting.number(1e19) == "10000000000000000000")
        #expect(HomeFormatting.number(1e19 + 0.5) == "10000000000000000000")
    }

    // MARK: - formatMinutes (`HomeScreen.kt:429-430`)

    @Test(
        "a minute of day is two zero-padded fields",
        arguments: [
            (0, "00:00"),
            (1, "00:01"),
            (8 * 60, "08:00"),
            (12 * 60 + 5, "12:05"),
            (22 * 60, "22:00"),
            (1439, "23:59")
        ]
    )
    func minutes(minuteOfDay: Int, expected: String) {
        #expect(HomeFormatting.minutes(minuteOfDay, locale: .current) == expected)
    }

    /// The view locale reaches this one — Kotlin passes `LocalLocale.current.platformLocale`
    /// (`HomeScreen.kt:221`) — and Turkish renders the same ASCII digits, so the clock reads
    /// identically on both platforms and in both languages.
    @Test("the view locale formats the clock, and Turkish renders the same digits")
    func minutesInTheViewLocale() {
        #expect(HomeFormatting.minutes(1439, locale: Self.turkish) == "23:59")
        #expect(HomeFormatting.minutes(8 * 60, locale: Self.turkish) == "08:00")
        #expect(
            HomeFormatting.minutes(8 * 60, locale: Self.turkish)
                == HomeFormatting.minutes(8 * 60, locale: Locale(identifier: "en_US"))
        )
    }
}
