// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/detail/MedicationDetailSections.kt:179-222` (`MedicationSupplyCard`).
//
// Its own file rather than a fourth section in `MedicationDetailSections.swift`: Kotlin keeps all
// five sections in one 347-line file, and five here would run that one past the 500-line limit
// (`CLAUDE.md`'s lint gate).
//
// Drawn only when `MedicationDetailUiState.showSupply` says stock tracking is on. There is no
// stock-adjust affordance here — stock moves when a dose is recorded, on both platforms.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// "Kutu & Stok" (`MedicationDetailSections.kt:183-222`).
///
/// The bar follows the one stock rule in ``StockBar``: three thresholds' worth is a full bar, rose
/// at or below the threshold, and no bar at all without a threshold.
struct MedicationSupplyCard: View {
    let medication: Medication
    let daysOfSupply: Int?

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // `val remaining = medication.stockCount ?: return` (`MedicationDetailSections.kt:185`).
        if let remaining = medication.stockCount {
            SalusCard {
                VStack(alignment: .leading, spacing: SalusSpacing.md) {
                    Text(verbatim: MedicationsStrings.detailSupplyTitle)
                        .font(SalusTypography.titleLarge.font)
                        .foregroundStyle(theme.colorScheme.onSurface)

                    VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                        SalusMetricTile(
                            overline: MedicationsStrings.detailStock,
                            value: formatAmount(remaining),
                            unit: medication.strengthUnit,
                            large: true
                        )
                        // `daysOfSupply?.let { … }` (`MedicationDetailSections.kt:198-205`).
                        if let days = daysOfSupply {
                            Text(verbatim: MedicationsStrings.detailDaysOfSupply(days: days))
                                .font(SalusTypography.bodyMedium.font)
                                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                        }
                    }

                    // `medication.stockThreshold?.let { … }` (`MedicationDetailSections.kt:206-220`).
                    if let threshold = medication.stockThreshold {
                        SalusProgressBar(
                            progress: StockBar.fill(remaining: remaining, threshold: threshold),
                            tone: StockBar.tone(remaining: remaining, threshold: threshold)
                        )
                        SalusStatusChip(
                            label: MedicationsStrings.detailThreshold(amount: formatAmount(threshold)),
                            status: medication.isLowOnStock ? .warning : .neutral
                        )
                    }
                }
            }
        }
    }
}
