// Ported from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/
// ui/calendar/CycleAnalysisCard.kt` — the M15 analysis card that says where the cycle stands.
//
// `state.averageCycleLength` is deliberately not drawn, on either platform: the field exists so the
// ViewModel can carry it (and the AI summary can read it), and Kotlin's card never renders it. A
// number here that Android does not show would be a port bug, not an improvement.
//
// Every sentence is a *prediction*, and says so. Nothing on this card is written to the database —
// `CyclePredictor` recomputes it from the recorded periods on every rebuild.
//
// The card's shape is Android's (`CycleAnalysisCard.kt:32-81`): the "DÖNGÜ ANALİZİ" overline with
// the confidence chip at its trailing edge, the cycle-day number as the `titleLarge` headline, the
// next-prediction sentence, and the irregularity `SalusInfoNote` at the foot. The confidence chip
// carries the prediction's `SalusStatus` — low confidence is a caution, not an error: the
// prediction is still shown, just qualified (`CycleAnalysisCard.kt:90-94`).

import SalusDesignSystem
import SalusUI
import SwiftUI

/// Cycle day, the next predicted start, confidence and the irregularity note
/// (`CycleAnalysisCard.kt:27-82`).
struct CycleSummaryCard: View {
    let state: CycleUiState

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard {
            // `SalusCard`'s own column is already `spacing: 0`, which is Kotlin's `Column` with no
            // `verticalArrangement`; the inner stack is here only to hang `fillMaxWidth`
            // (`CycleAnalysisCard.kt:33`) on one view instead of on every line.
            VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                // `Row { Text(overline, weight(1f)); SalusStatusChip }` (`CycleAnalysisCard.kt:33-53`).
                HStack(spacing: SalusSpacing.sm) {
                    Text(verbatim: CycleStrings.analysisTitle)
                        .font(SalusTypography.labelSmall.font)
                        .tracking(SalusTypography.labelSmall.tracking)
                        .foregroundStyle(theme.extendedColors.overline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let confidence = state.confidence {
                        SalusStatusChip(
                            label: CycleStrings.confidenceChip(CycleStrings.confidenceLabel(confidence)),
                            status: confidence.status
                        )
                    }
                }

                // `state.cycleDayNumber?.let { … }` (`CycleAnalysisCard.kt:55-61`) — absent before
                // the first recorded period.
                if let day = state.cycleDayNumber {
                    Text(verbatim: CycleStrings.dayNumber(day))
                        .font(SalusTypography.titleLarge.font)
                        .tracking(SalusTypography.titleLarge.tracking)
                        .foregroundStyle(theme.colorScheme.onSurface)
                }

                Text(verbatim: predictionText)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)

                // `CycleAnalysisCard.kt:75-80`.
                if state.isIrregular {
                    SalusInfoNote(
                        text: CycleStrings.irregular,
                        systemImage: "info.circle",
                        tone: .warning
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The four-armed `when` on `daysUntilNextPeriod` (`CycleAnalysisCard.kt:63-73`): no
    /// prediction, one ahead, the predicted day itself, or one that has come and gone.
    private var predictionText: String {
        guard let daysUntil = state.daysUntilNextPeriod else { return CycleStrings.noPrediction }
        if daysUntil > 0 {
            return CycleStrings.daysUntilPeriod(daysUntil)
        }
        if daysUntil == 0 {
            return CycleStrings.periodDueToday
        }
        return CycleStrings.periodOverdue(-daysUntil)
    }
}

/// The status a confidence level reads as (`CycleAnalysisCard.kt:90-94`): low confidence is a
/// caution, not an error — the prediction is still shown, just qualified.
extension CycleConfidence {
    fileprivate var status: SalusStatus {
        switch self {
        case .low: .warning
        case .medium: .neutral
        case .high: .success
        }
    }
}
