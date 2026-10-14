// Ported from the price conversions at the foot of `feature/smoking/src/main/kotlin/com/alicansekban/
// salus/feature/smoking/ui/common/SmokingMoney.kt` and from `PriceSheet.kt`'s two helpers.
//
// What the person types (a pack or pouch price, a vape's weekly spend) and what is stored (the cost
// of one unit) are told apart here, for the setup and the settings alike, so the two screens can
// never round differently (contract §8.11). The setup keeps its own copy of the arithmetic in
// `SmokingSetupUiState.price`; the settings sheet goes through these so the round trip
// "open, save untouched" is a tested property, not a hope.

import SalusSmoking

/// The units a standard pack holds. The pack size is not stored, so the sheet assumes the common
/// one and lets the person change it.
let defaultUnitsPerPack = 20

private let daysPerWeek: Int64 = 7

/// A pack or pouch price over its size, rounded half up in integer arithmetic: `(2p + n) / 2n`.
func unitCostFromPackPrice(priceMinor: Int64, unitsPerPack: Int) -> Int64 {
    let size = Int64(unitsPerPack)
    return (2 * priceMinor + size) / (2 * size)
}

/// A vape's weekly spend over seven, rounded half up: the core's own rule, not a second copy of it.
func unitCostFromWeeklySpend(weeklyMinor: Int64) -> Int64 {
    SmokingPrice.weeklySpend(weeklyMinor).unitCostMinor
}

/// The pack price a stored unit cost opens an editor at; converting it back gives the same cost.
func packPriceOf(unitCostMinor: Int64, unitsPerPack: Int) -> Int64 {
    unitCostMinor * Int64(unitsPerPack)
}

/// The weekly spend a stored daily vape cost opens an editor at.
func weeklySpendOf(unitCostMinor: Int64) -> Int64 {
    unitCostMinor * daysPerWeek
}

/// Where the price sheet starts: the amount the person thinks in (a pack price, or a vape's week)
/// and the pack size.
struct PriceSheetStart: Equatable {
    let priceText: String
    let unitsPerPack: Int

    /// A stored unit cost opened as the setup asked for it: priced per pack of 20, or per week for
    /// a vape.
    static func of(product: ProductType, unitCostMinor: Int64, fractionDigits: Int) -> PriceSheetStart {
        let minor = product == .vape
            ? weeklySpendOf(unitCostMinor: unitCostMinor)
            : packPriceOf(unitCostMinor: unitCostMinor, unitsPerPack: defaultUnitsPerPack)
        return PriceSheetStart(
            priceText: plainAmount(minor: minor, fractionDigits: fractionDigits),
            unitsPerPack: defaultUnitsPerPack
        )
    }
}

/// The unit cost the typed amount stands for, or `nil` when it is unreadable or rounds to nothing.
/// The same conversion the setup uses, so a price entered here and one entered there agree.
func priceSheetUnitCost(text: String, fractionDigits: Int, vape: Bool, unitsPerPack: Int) -> Int64? {
    guard let minor = parseMinorUnits(text, fractionDigits: fractionDigits), minor > 0 else { return nil }
    let unitCost = vape
        ? unitCostFromWeeklySpend(weeklyMinor: minor)
        : unitCostFromPackPrice(priceMinor: minor, unitsPerPack: unitsPerPack)
    return unitCost > 0 ? unitCost : nil
}
