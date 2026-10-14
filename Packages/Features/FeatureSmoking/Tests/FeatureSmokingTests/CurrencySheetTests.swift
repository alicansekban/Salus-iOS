// Twin of `CurrencySheetTest.kt` (contract section 8.11): relabelling keeps the stored minor units,
// so the settings sheet offers only currencies with the current one's number of fraction digits.

import Testing

@testable import FeatureSmoking

@Suite("CurrencySheet choices")
struct CurrencySheetTests {
    @Test("a two-digit currency is offered the common two-digit currencies")
    func twoDigitCurrency() {
        #expect(sheetCurrencyChoices(selected: "TRY") == ["TRY", "EUR", "USD", "GBP", "CHF"])
        #expect(sheetCurrencyChoices(selected: "SEK") == ["SEK", "TRY", "EUR", "USD", "GBP", "CHF"])
    }

    @Test("a zero-digit currency is offered no two-digit currency")
    func zeroDigitCurrency() {
        // JPY has no minor unit: relabelling 12 345 minor TRY as JPY would show 12 345 yen, not 123.45.
        #expect(sheetCurrencyChoices(selected: "JPY") == ["JPY"])
    }

    @Test("a three-digit currency is offered only three-digit currencies")
    func threeDigitCurrency() {
        #expect(sheetCurrencyChoices(selected: "KWD") == ["KWD"])
    }

    @Test("an unknown code counts as two digits, like the money formatter")
    func unknownCode() {
        #expect(sheetCurrencyChoices(selected: "ZZZ") == ["ZZZ", "TRY", "EUR", "USD", "GBP", "CHF"])
    }

    @Test("the setup list is unchanged: the sheet filters, the setup does not")
    func setupListIsUnchanged() {
        #expect(currencyChoices(selected: "JPY") == ["JPY", "TRY", "EUR", "USD", "GBP", "CHF"])
    }
}
