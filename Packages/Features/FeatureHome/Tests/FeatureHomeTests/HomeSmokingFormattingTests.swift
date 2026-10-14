// The card's pure display rules: the unit the next-stage countdown reads in, whole-unit money and
// the ring's percent. Android keeps the first two private to `HomeSmokingCards.kt` and tests none
// of them; the boundary rows here are the contract's "coarsest unit that still reads as a count,
// rounded up, never zero minutes".

import Foundation
import Testing

@testable import FeatureHome

@Suite("HomeSmokingFormatting")
struct HomeSmokingFormattingTests {
    private static let minute: Int64 = 60000
    private static let hour: Int64 = 3_600_000
    private static let day: Int64 = 86_400_000

    struct UnitRow: Sendable, CustomTestStringConvertible {
        let remainingMs: Int64
        let unit: HomeSmokingFormatting.NextStageUnit
        let count: Int

        var testDescription: String { "\(remainingMs) ms → \(count) \(unit)" }
    }

    static let unitRows: [UnitRow] = [
        // A stage seconds away never says zero minutes.
        UnitRow(remainingMs: 0, unit: .minutes, count: 1),
        UnitRow(remainingMs: 1, unit: .minutes, count: 1),
        UnitRow(remainingMs: minute, unit: .minutes, count: 1),
        // Rounded up: "2 minutes" never promises the stage sooner than it comes.
        UnitRow(remainingMs: minute + 1, unit: .minutes, count: 2),
        UnitRow(remainingMs: hour - 1, unit: .minutes, count: 60),
        // The hour boundary switches the unit.
        UnitRow(remainingMs: hour, unit: .hours, count: 1),
        UnitRow(remainingMs: hour + 1, unit: .hours, count: 2),
        UnitRow(remainingMs: day - 1, unit: .hours, count: 24),
        UnitRow(remainingMs: day, unit: .days, count: 1),
        UnitRow(remainingMs: 3 * day, unit: .days, count: 3),
        UnitRow(remainingMs: 3 * day + 1, unit: .days, count: 4)
    ]

    @Test("the next stage reads in the coarsest unit that is a count, rounded up", arguments: unitRows)
    func nextStageUnit(row: UnitRow) {
        let (unit, count) = HomeSmokingFormatting.nextStageUnit(remainingMs: row.remainingMs)

        #expect(unit == row.unit)
        #expect(count == row.count)
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
