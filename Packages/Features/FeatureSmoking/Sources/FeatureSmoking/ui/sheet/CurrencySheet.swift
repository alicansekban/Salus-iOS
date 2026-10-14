// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/sheet/
// CurrencySheet.kt`.
//
// Picks the plan's currency from the same short list the setup offers (the current one first when it
// is not on it). Choosing hands the code out at once; the screen then asks to confirm, because the
// change relabels the amounts and never converts them. The sheet only chooses, it writes nothing.
//
// Compose → SwiftUI: `FlowRow` of chips → `ChipFlowLayout`.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The sheet's body: the currency chips and the sentence that says what a change does.
struct CurrencySheet: View {
    let selected: String
    let onPick: (String) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            ChipFlowLayout(spacing: SalusSpacing.sm) {
                ForEach(currencyChoices(selected: selected), id: \.self) { code in
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
