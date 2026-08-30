// Ported from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/
// ui/calendar/CycleScreen.kt:331-375` — the one card that says where the cycle stands.
//
// `state.averageCycleLength` is deliberately not drawn, on either platform: the field exists so the
// ViewModel can carry it (and the AI summary can read it), and Kotlin's card never renders it. A
// number here that Android does not show would be a port bug, not an improvement.
//
// Every sentence is a *prediction*, and says so: `cycle_days_until_period` and
// `cycle_period_overdue` both open with "Tahmini". Nothing on this card is written to the database
// — `CyclePredictor` recomputes it from the recorded periods on every rebuild.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// Cycle day, the next predicted start, confidence and the irregularity note
/// (`CycleScreen.kt:331-375`).
struct CycleSummaryCard: View {
    let state: CycleUiState

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard {
            // `SalusCard`'s own column is already `spacing: 0`, which is Kotlin's `Column` with no
            // `verticalArrangement`; the inner stack is here only to hang `fillMaxWidth`
            // (`CycleScreen.kt:333`) on one view instead of on every line.
            VStack(alignment: .leading, spacing: 0) {
                // `state.cycleDayNumber?.let { … }` (`CycleScreen.kt:334-339`) — absent before the
                // first recorded period.
                if let day = state.cycleDayNumber {
                    Text(verbatim: CycleStrings.dayNumber(day))
                        .font(SalusTypography.titleMedium.font)
                        .tracking(SalusTypography.titleMedium.tracking)
                        .foregroundStyle(theme.colorScheme.onSurface)
                }

                Text(verbatim: predictionText)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)

                // `state.confidence?.let { … }` (`CycleScreen.kt:359-365`). The label is resolved
                // first and handed to the outer string, exactly as Kotlin nests the two
                // `stringResource` calls.
                if let confidence = state.confidence {
                    supporting(CycleStrings.confidence(CycleStrings.confidenceLabel(confidence)))
                }

                // `CycleScreen.kt:367-373`.
                if state.isIrregular {
                    supporting(CycleStrings.irregular)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The three-armed `when` on `daysUntilNextPeriod` (`CycleScreen.kt:341-357`): no prediction,
    /// a prediction ahead, or one that has come and gone.
    private var predictionText: String {
        guard let daysUntil = state.daysUntilNextPeriod else { return CycleStrings.noPrediction }
        return daysUntil >= 0 ? CycleStrings.daysUntilPeriod(daysUntil) : CycleStrings.periodOverdue(-daysUntil)
    }

    /// The two `bodySmall` / `onSurfaceVariant` lines below the prediction.
    private func supporting(_ text: String) -> some View {
        Text(verbatim: text)
            .font(SalusTypography.bodySmall.font)
            .tracking(SalusTypography.bodySmall.tracking)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
    }
}
