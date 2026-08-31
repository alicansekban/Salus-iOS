import Foundation
import Testing

@testable import SalusPremium

// Ported 1:1 from `MonthlyEquivalentTest.kt` (5 cases). Case names are the
// Kotlin backtick names in camelCase.

@Suite("MonthlyEquivalent (Android parity)")
struct MonthlyEquivalentTests {
    @Test("a monthly plan has no monthly equivalent")
    func aMonthlyPlanHasNoMonthlyEquivalent() {
        #expect(
            monthlyEquivalentOf(
                amountMicros: 29_990_000,
                currencyCode: "USD",
                period: .monthly,
                locale: Locale(identifier: "en_US")
            ) == nil
        )
    }

    @Test("an annual price is divided by twelve and formatted in the store currency")
    func anAnnualPriceIsDividedByTwelveAndFormattedInTheStoreCurrency() {
        #expect(
            monthlyEquivalentOf(
                amountMicros: 359_880_000,
                currencyCode: "USD",
                period: .annual,
                locale: Locale(identifier: "en_US")
            ) == "$29.99"
        )
    }

    @Test("a six month price is divided by six")
    func aSixMonthPriceIsDividedBySix() {
        #expect(
            monthlyEquivalentOf(
                amountMicros: 179_940_000,
                currencyCode: "USD",
                period: .sixMonth,
                locale: Locale(identifier: "en_US")
            ) == "$29.99"
        )
    }

    @Test("the formatted currency follows the requested locale")
    func theFormattedCurrencyFollowsTheRequestedLocale() {
        #expect(
            monthlyEquivalentOf(
                amountMicros: 359_880_000,
                currencyCode: "TRY",
                period: .annual,
                locale: Locale(identifier: "tr_TR")
            ) == "₺29,99"
        )
    }

    @Test("an unknown currency code yields no monthly equivalent")
    func anUnknownCurrencyCodeYieldsNoMonthlyEquivalent() {
        #expect(
            monthlyEquivalentOf(
                amountMicros: 359_880_000,
                currencyCode: "not-a-currency",
                period: .annual,
                locale: .current
            ) == nil
        )
    }
}
