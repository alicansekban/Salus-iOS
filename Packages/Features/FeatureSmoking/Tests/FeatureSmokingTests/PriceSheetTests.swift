// Ported from `feature/smoking/src/test/kotlin/com/alicansekban/salus/feature/smoking/ui/sheet/
// PriceSheetTest.kt`: the settings price sheet converts between what the person types (a pack
// price, a vape's weekly spend) and the unit cost that is stored, with the setup's own rounding
// (contract §8.11).

import SalusSmoking
import Testing

@testable import FeatureSmoking

@Suite("PriceSheet conversion")
struct PriceSheetTests {
    @Test("a pack product opens at the pack price of twenty and the standard pack size")
    func packProductOpensAtThePackPrice() {
        let start = PriceSheetStart.of(product: .cigarette, unitCostMinor: 475, fractionDigits: 2)

        #expect(start.priceText == "95")
        #expect(start.unitsPerPack == 20)
    }

    @Test("a vape opens at the weekly spend")
    func vapeOpensAtTheWeeklySpend() {
        let start = PriceSheetStart.of(product: .vape, unitCostMinor: 143, fractionDigits: 2)

        #expect(start.priceText == "10.01")
    }

    @Test("the saved unit cost is the pack price over the pack size, rounded half up")
    func unitCostIsPackPriceOverSizeRoundedHalfUp() {
        #expect(priceSheetUnitCost(text: "97.50", fractionDigits: 2, vape: false, unitsPerPack: 20) == 488)
        #expect(priceSheetUnitCost(text: "100.05", fractionDigits: 2, vape: false, unitsPerPack: 30) == 334)
    }

    @Test("the saved cost of a vape is the weekly spend over seven")
    func vapeCostIsWeeklySpendOverSeven() {
        #expect(priceSheetUnitCost(text: "10", fractionDigits: 2, vape: true, unitsPerPack: 20) == 143)
    }

    @Test("an unreadable amount or one that rounds to nothing saves nothing")
    func unreadableOrZeroSavesNothing() {
        #expect(priceSheetUnitCost(text: "abc", fractionDigits: 2, vape: false, unitsPerPack: 20) == nil)
        #expect(priceSheetUnitCost(text: "0", fractionDigits: 2, vape: false, unitsPerPack: 20) == nil)
        // 0.04 over 20 is less than half a minor unit.
        #expect(priceSheetUnitCost(text: "0.04", fractionDigits: 2, vape: false, unitsPerPack: 20) == nil)
    }

    @Test(
        "opening a sheet and saving it untouched returns the stored unit cost",
        arguments: [ProductType.cigarette, .rolled, .heated, .vape]
    )
    func untouchedSheetRoundTrips(product: ProductType) {
        let start = PriceSheetStart.of(product: product, unitCostMinor: 476, fractionDigits: 2)

        #expect(
            priceSheetUnitCost(
                text: start.priceText,
                fractionDigits: 2,
                vape: product == .vape,
                unitsPerPack: start.unitsPerPack
            ) == 476
        )
    }

    @Test("a zero-decimal currency opens and saves in whole units")
    func zeroDecimalCurrency() {
        let start = PriceSheetStart.of(product: .cigarette, unitCostMinor: 120, fractionDigits: 0)

        #expect(start.priceText == "2400")
        #expect(priceSheetUnitCost(text: "2400", fractionDigits: 0, vape: false, unitsPerPack: 20) == 120)
    }
}
