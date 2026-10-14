// The card's pure display rules: the next-stage countdown's text, whole-unit money and the ring's
// percent. The countdown's rounding is `SalusSmoking.StageTimeLeft` (contract section 8.15, shared
// with Main and the timeline); these rows pin that Home speaks it, not its own copy.

import Foundation
import Testing

@testable import FeatureHome

@Suite("HomeSmokingFormatting")
struct HomeSmokingFormattingTests {
    private static let minute: Int64 = 60000
    private static let hour: Int64 = 3_600_000
    private static let day: Int64 = 86_400_000

    struct TextRow: Sendable, CustomTestStringConvertible {
        let remainingMs: Int64
        // What the card must say, named by the accessor rather than a literal so the row holds in
        // both locales.
        let expected: @Sendable () -> String
        let note: String

        var testDescription: String { "\(remainingMs) ms → \(note)" }
    }

    /// Contract section 8.15: the one rounded-up rule, so the unit follows the rounded count.
    static let textRows: [TextRow] = [
        // A stage seconds away never says zero minutes.
        TextRow(remainingMs: 0, expected: { HomeStrings.smokingNextMinutes(1) }, note: "1 minute"),
        TextRow(remainingMs: minute + 1, expected: { HomeStrings.smokingNextMinutes(2) }, note: "2 minutes"),
        TextRow(remainingMs: 59 * minute, expected: { HomeStrings.smokingNextMinutes(59) }, note: "59 minutes"),
        // 59 min 30 s rounds to 60 minutes, which is one hour: never "60 minutes".
        TextRow(remainingMs: 59 * minute + 30000, expected: { HomeStrings.smokingNextHours(1) }, note: "1 hour"),
        TextRow(remainingMs: hour, expected: { HomeStrings.smokingNextHours(1) }, note: "1 hour"),
        TextRow(remainingMs: hour + 1, expected: { HomeStrings.smokingNextHours(2) }, note: "2 hours"),
        TextRow(remainingMs: 23 * hour, expected: { HomeStrings.smokingNextHours(23) }, note: "23 hours"),
        // 23 h 59 min rounds to 24 hours, which is one day: never "24 hours".
        TextRow(remainingMs: 23 * hour + 59 * minute, expected: { HomeStrings.smokingNextDays(1) }, note: "1 day"),
        TextRow(remainingMs: day, expected: { HomeStrings.smokingNextDays(1) }, note: "1 day"),
        TextRow(remainingMs: 2 * day + 23 * hour, expected: { HomeStrings.smokingNextDays(3) }, note: "3 days"),
        TextRow(remainingMs: 3 * day + 1, expected: { HomeStrings.smokingNextDays(4) }, note: "4 days")
    ]

    @Test("the next stage reads on the shared rounded-up rule (StageTimeLeft)", arguments: textRows)
    func nextStageText(row: TextRow) {
        #expect(HomeSmokingFormatting.nextStageText(remainingMs: row.remainingMs) == row.expected())
    }

    @Test("whole-unit money rounds half up and keeps the currency's own symbol")
    func wholeMoney() {
        let turkish = Locale(identifier: "tr_TR")
        let american = Locale(identifier: "en_US")

        #expect(HomeSmokingFormatting.wholeMoney(minor: 315_000, currencyCode: "TRY", locale: turkish) == "₺3.150")
        // 3150.50 → 3151: half up, not banker's rounding (which would give 3150).
        #expect(HomeSmokingFormatting.wholeMoney(minor: 315_050, currencyCode: "TRY", locale: turkish) == "₺3.151")
        #expect(HomeSmokingFormatting.wholeMoney(minor: 315_049, currencyCode: "TRY", locale: turkish) == "₺3.150")
        #expect(HomeSmokingFormatting.wholeMoney(minor: 315_000, currencyCode: "USD", locale: american) == "$3,150")
        // A zero-decimal currency's minor unit is the whole unit.
        #expect(HomeSmokingFormatting.wholeMoney(minor: 3150, currencyCode: "JPY", locale: american) == "¥3,150")
    }

    @Test("an unknown currency code still formats instead of trapping")
    func unknownCurrencyFormats() {
        let text = HomeSmokingFormatting.wholeMoney(
            minor: 12345,
            currencyCode: "ZZZZ",
            locale: Locale(identifier: "en_US")
        )

        #expect(text.contains("123"))
    }

    @Test("the ring's percent follows the locale")
    func percent() {
        #expect(HomeSmokingFormatting.percent(permille: 700, locale: Locale(identifier: "tr_TR")) == "%70")
        #expect(HomeSmokingFormatting.percent(permille: 700, locale: Locale(identifier: "en_US")) == "70%")
        #expect(HomeSmokingFormatting.percent(permille: 0, locale: Locale(identifier: "en_US")) == "0%")
    }
}
