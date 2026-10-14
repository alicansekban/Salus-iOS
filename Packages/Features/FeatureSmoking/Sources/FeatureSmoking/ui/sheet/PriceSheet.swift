// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/sheet/
// PriceSheet.kt`.
//
// Edits the price the way the setup asked for it: a pack or pouch price and how many units it holds
// (a vape: the weekly spend), converted to the unit cost that is stored. It opens at the stored cost
// times 20 (times 7 for a vape); the pack size is not stored, so 20 is the standard one and can be
// changed here. An unreadable or zero amount keeps "Kaydet" off. A new price starts today and
// earlier days keep theirs, which the note says. `writing` disables the button while the write is in
// flight; closing or swiping away writes nothing. The conversions are in `SmokingPriceEditing.swift`.
//
// Compose → SwiftUI: `SalusTextField(keyboardOptions = Decimal)` → `SalusTextField(keyboard:
// .decimal)`; `SalusStepperField` → `SetupIntStepper`; `rememberSaveable` → `@State`.

import SalusDesignSystem
import SalusSmoking
import SalusUI
import SwiftUI

/// The body of the price sheet, with its own state.
struct PriceSheet: View {
    let currencyCode: String
    let product: ProductType
    let writing: Bool
    let onSave: (Int64) -> Void

    @State private var text: String
    @State private var unitsPerPack: Int

    init(
        currencyCode: String,
        unitCostMinor: Int64,
        product: ProductType,
        writing: Bool,
        onSave: @escaping (Int64) -> Void
    ) {
        self.currencyCode = currencyCode
        self.product = product
        self.writing = writing
        self.onSave = onSave
        let start = PriceSheetStart.of(
            product: product,
            unitCostMinor: unitCostMinor,
            fractionDigits: fractionDigits(ofCurrency: currencyCode)
        )
        _text = State(initialValue: start.priceText)
        _unitsPerPack = State(initialValue: start.unitsPerPack)
    }

    private var unitCost: Int64? {
        priceSheetUnitCost(
            text: text,
            fractionDigits: fractionDigits(ofCurrency: currencyCode),
            vape: product == .vape,
            unitsPerPack: unitsPerPack
        )
    }

    var body: some View {
        PriceSheetContent(
            text: $text,
            currencyCode: currencyCode,
            product: product,
            unitsPerPack: unitsPerPack,
            valid: unitCost != nil,
            writing: writing,
            onUnitsPerPackChange: { unitsPerPack = $0 },
            onSave: {
                if let unitCost {
                    onSave(unitCost)
                }
            }
        )
        .interactiveDismissDisabled(writing)
    }
}

/// The sheet's body without its state, so a preview can draw every case.
struct PriceSheetContent: View {
    @Binding var text: String
    let currencyCode: String
    let product: ProductType
    let unitsPerPack: Int
    let valid: Bool
    let writing: Bool
    let onUnitsPerPackChange: (Int) -> Void
    let onSave: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.salusTheme) private var theme

    var body: some View {
        let rolled = product == .rolled
        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            SalusTextField(
                text: $text,
                label: label,
                placeholder: "0",
                suffix: currencySymbol(of: currencyCode, locale: locale),
                keyboard: .decimal
            )
            if product != .vape {
                SetupIntStepper(
                    label: rolled ? SmokingStrings.setupUnitsPerPouch : SmokingStrings.setupUnitsPerPack,
                    value: unitsPerPack,
                    unit: SmokingStrings.setupUnitsPerPackUnit,
                    onChange: onUnitsPerPackChange
                )
            }
            Text(verbatim: SmokingStrings.settingsPriceNote)
                .font(SalusTypography.bodySmall.font)
                .tracking(SalusTypography.bodySmall.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            SalusButton(
                SmokingStrings.settingsSave,
                accent: theme.extendedColors.smoking,
                enabled: valid && !writing,
                action: onSave
            )
        }
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.bottom, SalusSpacing.xl)
    }

    private var label: String {
        switch product {
        case .vape: SmokingStrings.setupWeeklySpend
        case .rolled: SmokingStrings.setupPouchPrice
        case .cigarette, .heated: SmokingStrings.setupPackPrice
        }
    }
}

// MARK: - Previews

#Preview("Price sheet — pack and unreadable vape") {
    SalusPreviewPalettes {
        PriceSheetContent(
            text: .constant("95"),
            currencyCode: "TRY",
            product: .cigarette,
            unitsPerPack: 20,
            valid: true,
            writing: false,
            onUnitsPerPackChange: { _ in },
            onSave: {}
        )
        // An unreadable amount: "Kaydet" is off.
        PriceSheetContent(
            text: .constant("4,7,5"),
            currencyCode: "EUR",
            product: .vape,
            unitsPerPack: 20,
            valid: false,
            writing: false,
            onUnitsPerPackChange: { _ in },
            onSave: {}
        )
    }
}

#Preview("Price sheet — accessibility3") {
    PriceSheetContent(
        text: .constant("95"),
        currencyCode: "TRY",
        product: .rolled,
        unitsPerPack: 20,
        valid: true,
        writing: false,
        onUnitsPerPackChange: { _ in },
        onSave: {}
    )
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
    .dynamicTypeSize(.accessibility3)
}
