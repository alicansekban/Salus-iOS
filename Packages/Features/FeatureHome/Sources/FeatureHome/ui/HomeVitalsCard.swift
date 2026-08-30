// Ported from `HomeScreen.kt:350-404` — the latest weight, blood pressure and glucose.
//
// Three conditions, all Kotlin's:
//   `hasAnything`                       — nothing recorded at all is one empty line and no rows
//                                         (`HomeScreen.kt:353-358`).
//   `weightTrend.size >= 2`             — the sparkline needs two points to be a line
//                                         (`HomeScreen.kt:367`); `SalusSparkline` draws nothing
//                                         below that either, but the guard stays where Kotlin
//                                         has it so the 96×32 slot is not reserved for a blank.
//   `systolic != null && diastolic != null` — one half of a reading is not a reading
//                                         (`HomeScreen.kt:376`).
//
// The glucose line is the one place the port does arithmetic Kotlin spells inline: the snapshot
// always carries mg/dL, and `GlucoseConversion.fromMgDl(_:unit:)` is the twin of
// `mgdl / GlucoseConversion.MG_DL_PER_MMOL_L` (`HomeScreen.kt:394`) — with the mg/dL arm the
// identity, exactly as the Kotlin `when` leaves it unconverted.
//
// The sparkline is `.accessibilityHidden(true)` inside `SalusSparkline` itself: the weight beside
// it is already spoken, and Compose gives its `Canvas` no `contentDescription` either.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// The vitals snapshot (`HomeScreen.kt:351-403`).
struct HomeVitalsCard: View {
    let vitals: VitalsSnapshot
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme

    /// `hasAnything` (`HomeScreen.kt:353-354`).
    private var hasAnything: Bool {
        vitals.latestWeightKg != nil || vitals.latestSystolic != nil || vitals.latestGlucoseMgdl != nil
    }

    var body: some View {
        HomeDashboardCard(onTap: onTap) {
            if hasAnything {
                weightRow
                bloodPressureLine
                glucoseLine
            } else {
                HomeEmptyLine(text: HomeStrings.vitalsEmpty)
            }
        }
    }

    /// The weight text and, when there is a trend to draw, the sparkline beside it
    /// (`HomeScreen.kt:360-375`).
    @ViewBuilder private var weightRow: some View {
        if let weight = vitals.latestWeightKg {
            HStack(spacing: 0) {
                line(HomeStrings.vitalsWeight(HomeFormatting.number(weight)))
                if vitals.weightTrend.count >= 2 {
                    SalusSparkline(
                        values: vitals.weightTrend,
                        lineColor: theme.extendedColors.vitals.accent
                    )
                    .frame(width: HomeFormatting.sparklineWidth, height: HomeFormatting.sparklineHeight)
                }
            }
        }
    }

    /// `today_vitals_bp`, only with both halves (`HomeScreen.kt:376-386`).
    @ViewBuilder private var bloodPressureLine: some View {
        if let systolic = vitals.latestSystolic, let diastolic = vitals.latestDiastolic {
            line(HomeStrings.vitalsBloodPressure(
                HomeFormatting.number(systolic),
                HomeFormatting.number(diastolic)
            ))
            .padding(.top, SalusSpacing.xs)
        }
    }

    /// The glucose reading in the unit the user reads in (`HomeScreen.kt:387-402`).
    @ViewBuilder private var glucoseLine: some View {
        if let mgdl = vitals.latestGlucoseMgdl {
            let value = GlucoseConversion.fromMgDl(mgdl, unit: vitals.glucoseUnit)
            line(HomeStrings.vitalsGlucose(HomeFormatting.number(value), unit: vitals.glucoseUnit))
                .padding(.top, SalusSpacing.xs)
        }
    }

    /// The shared row style: `bodyMedium`, `weight(1f)` (`HomeScreen.kt:363-366`, `:383-384`,
    /// `:398-400`). Greedy so the sparkline is pushed to the trailing edge on the weight row and
    /// the two lines below start at the same inset.
    private func line(_ text: String) -> some View {
        // `verbatim:` because the caller hands over a resolved string; the plain initializer would
        // treat it as a `LocalizedStringKey` and look it up in the *main* bundle.
        Text(verbatim: text)
            .font(SalusTypography.bodyMedium.font)
            .tracking(SalusTypography.bodyMedium.tracking)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
