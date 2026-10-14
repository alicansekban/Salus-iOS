// Ported from `feature/smoking/src/test/kotlin/com/alicansekban/salus/feature/smoking/ui/common/
// SmokingMoneyTest.kt`: money here is a minor-unit integer everywhere except the edge where a
// person types it and a screen shows it (contract §2).

import Foundation
import Testing

@testable import FeatureSmoking

@Suite("SmokingMoney")
struct SmokingMoneyTests {
    @Test("an amount is read into minor units with the currency's own decimals")
    func amountIsReadIntoMinorUnits() {
        #expect(parseMinorUnits("95", fractionDigits: 2) == 9500)
        #expect(parseMinorUnits("95,5", fractionDigits: 2) == 9550)
        #expect(parseMinorUnits(" 95.05 ", fractionDigits: 2) == 9505)
        #expect(parseMinorUnits("500", fractionDigits: 0) == 500)
        #expect(parseMinorUnits("1", fractionDigits: 3) == 1000)
    }

    @Test("text that is not a plain non-negative amount reads as nil")
    func notAnAmountReadsAsNil() {
        for text in ["", "  ", "abc", "-5", "1.234,5", "95.555", "1e3", "."] {
            #expect(parseMinorUnits(text, fractionDigits: 2) == nil, "'\(text)'")
        }
        #expect(parseMinorUnits("5.5", fractionDigits: 0) == nil, "a fraction in a currency without decimals")
    }

    @Test("ten whole digits are too many; nine are the ceiling")
    func wholeDigitsAreBounded() {
        #expect(parseMinorUnits("999999999", fractionDigits: 2) == 99_999_999_900)
        #expect(parseMinorUnits("1000000000", fractionDigits: 2) == nil)
    }

    @Test("the decimals of a currency come from its ISO definition")
    func decimalsComeFromTheCurrency() {
        #expect(fractionDigits(ofCurrency: "TRY") == 2)
        #expect(fractionDigits(ofCurrency: "JPY") == 0)
        // Anything that is not a currency falls back to two, the common case.
        #expect(fractionDigits(ofCurrency: "XXXX") == 2)
    }

    @Test("an amount in the field is written back without a trailing fraction it does not need")
    func plainAmountDropsUnneededFraction() {
        #expect(plainAmount(minor: 9500, fractionDigits: 2) == "95")
        #expect(plainAmount(minor: 9550, fractionDigits: 2) == "95.5")
        #expect(plainAmount(minor: 9505, fractionDigits: 2) == "95.05")
        #expect(plainAmount(minor: 500, fractionDigits: 0) == "500")
        #expect(plainAmount(minor: 0, fractionDigits: 2) == "0")
    }

    @Test("a money value is shown with the locale's symbol and no decimals when asked")
    func moneyIsFormattedForTheLocale() {
        let turkish = Locale(identifier: "tr_TR")

        #expect(formatMoney(minor: 9500, currencyCode: "TRY", locale: turkish, showFraction: false) == "₺95")
        #expect(formatMoney(minor: 3_467_500, currencyCode: "TRY", locale: turkish, showFraction: false) == "₺34.675")
        #expect(formatMoney(minor: 9550, currencyCode: "TRY", locale: turkish, showFraction: true) == "₺95,50")
    }

    @Test("whole-unit rounding is half up, not banker's")
    func wholeUnitRoundingIsHalfUp() {
        let turkish = Locale(identifier: "tr_TR")

        #expect(formatMoney(minor: 9550, currencyCode: "TRY", locale: turkish, showFraction: false) == "₺96")
        #expect(formatMoney(minor: 9450, currencyCode: "TRY", locale: turkish, showFraction: false) == "₺95")
        #expect(formatMoney(minor: 9650, currencyCode: "TRY", locale: turkish, showFraction: false) == "₺97")
    }

    @Test("the default currency follows the locale's country and falls back to lira")
    func defaultCurrencyFollowsTheCountry() {
        #expect(defaultCurrencyCode(for: Locale(identifier: "tr_TR")) == "TRY")
        #expect(defaultCurrencyCode(for: Locale(identifier: "en_US")) == "USD")
        #expect(defaultCurrencyCode(for: Locale(identifier: "de_DE")) == "EUR")
        // A language-only locale (the app's own per-app locale "tr") names no country.
        #expect(defaultCurrencyCode(for: Locale(identifier: "tr")) == "TRY")
        #expect(defaultCurrencyCode(for: Locale(identifier: "en")) == "TRY")
    }
}
