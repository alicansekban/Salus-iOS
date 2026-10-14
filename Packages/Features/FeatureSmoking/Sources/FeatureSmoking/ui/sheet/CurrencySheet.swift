// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/sheet/
// CurrencySheet.kt`.
//
// Picks the plan's currency from the setup's short list (the current one first when it is not on it),
// cut to the currencies with the current one's number of fraction digits (``sheetCurrencyChoices``).
// Choosing hands the code out at once; the screen then asks to confirm, because the change relabels
// the amounts and never converts them. The sheet only chooses, it writes nothing.
//
// Compose → SwiftUI: `FlowRow` of chips → `ChipFlowLayout`.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// ``currencyChoices(selected:)`` limited to currencies whose fraction digits equal the selected
/// one's. The stored amounts are minor units and a relabel keeps them, so a currency with another
/// digit count would show them x100 or /10 and make "the saved amount stays the same number" false
/// (contract section 8.11, parity D-M17-ac). An unknown code counts as two digits, as in the money
/// formatter (``fractionDigits(ofCurrency:)``). The setup's own list is not filtered: there is no
/// amount yet to relabel.
func sheetCurrencyChoices(selected: String) -> [String] {
    let digits = fractionDigits(ofCurrency: selected)
    return currencyChoices(selected: selected).filter { fractionDigits(ofCurrency: $0) == digits }
}

/// The sheet's body: the currency chips and the sentence that says what a change does.
struct CurrencySheet: View {
    let selected: String
    let onPick: (String) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            ChipFlowLayout(spacing: SalusSpacing.sm) {
                ForEach(sheetCurrencyChoices(selected: selected), id: \.self) { code in
                    SalusChoiceChip(
                        label: code,
                        isSelected: code == selected,
                        accent: theme.extendedColors.smoking
                    ) { onPick(code) }
                }
            }
            Text(verbatim: SmokingStrings.settingsCurrencyConfirmMessage)
                .font(SalusTypography.bodySmall.font)
                .tracking(SalusTypography.bodySmall.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
        }
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.bottom, SalusSpacing.xl)
    }
}

// MARK: - Previews

#Preview("Currency sheet — common and uncommon") {
    SalusPreviewPalettes {
        CurrencySheet(selected: "TRY", onPick: { _ in })
        // A currency outside the common list leads the row.
        CurrencySheet(selected: "SEK", onPick: { _ in })
    }
}

#Preview("Currency sheet — accessibility3") {
    CurrencySheet(selected: "EUR", onPick: { _ in })
        .salusTheme(SalusTheme.resolve(systemIsDark: false))
        .dynamicTypeSize(.accessibility3)
}
