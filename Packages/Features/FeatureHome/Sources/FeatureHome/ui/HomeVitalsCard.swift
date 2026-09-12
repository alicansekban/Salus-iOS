// Ported from `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/ui/HomePager.kt` —
// `VitalsPage` (`:272-325`), `PageEmptyState` (`:327-331`) and `MetricLine` (`:333-336`).
//
// The M15 page drops the per-row `SalusIconBadge` the pre-M15 card repeated three times: the badge
// is the card's now, in ``HomeSnapshotCard``'s title row, and each reading is one `titleMedium`
// line under it (`HomePager.kt:334-335`). The sparkline stops being a 96×32 slot beside the weight
// and becomes a full-width strip under it (`fillMaxWidth().height(SalusSpacing.xxl)`,
// `HomePager.kt:293-295`).
//
// Three conditions, all Kotlin's:
//   `hasAnything`                       — nothing recorded at all is the shared empty state and no
//                                         rows (`HomePager.kt:281-286`).
//   `weightTrend.size >= 2`             — the sparkline needs two points to be a line
//                                         (`HomePager.kt:290`); `SalusSparkline` draws nothing
//                                         below that either, but the guard stays where Kotlin has
//                                         it so the strip is not reserved for a blank.
//   `systolic != null && diastolic != null` — one half of a reading is not a reading
//                                         (`HomePager.kt:300`).
//
// The glucose line is the one place the port does arithmetic Kotlin spells inline: the snapshot
// always carries mg/dL, and `GlucoseConversion.fromMgDl(_:unit:)` is the twin of
// `mgdl / GlucoseConversion.MG_DL_PER_MMOL_L` (`HomePager.kt:309-322`) — with the mg/dL arm the
// identity, exactly as the Kotlin `when` leaves it unconverted.
//
// The sparkline is `.accessibilityHidden(true)` inside `SalusSparkline` itself: the weight beside
// it is already spoken, and Compose gives its `Canvas` no `contentDescription` either.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// The vitals snapshot (`VitalsPage`, `HomePager.kt:272-325`).
struct HomeVitalsCard: View {
    let vitals: VitalsSnapshot
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme

    /// `hasAnything` (`HomePager.kt:281-282`).
    private var hasAnything: Bool {
        vitals.latestWeightKg != nil || vitals.latestSystolic != nil || vitals.latestGlucoseMgdl != nil
    }

    var body: some View {
        // The page holds no interactive child, so the card can be the real `Button`
        // `SalusCard(onTap:)` builds — free button semantics, free VoiceOver
        // (``HomeDashboardCard``'s note). `MonitorHeart` → `waveform.path.ecg` (SF Symbol twin,
        // iOS 17 — a heart trace, the closest family symbol to Material's monitor-heart).
        HomeSnapshotCard(
            systemImage: "waveform.path.ecg",
            accent: theme.extendedColors.vitals,
            title: HomeStrings.vitalsTitle,
            onTap: onTap
        ) {
            if hasAnything {
                // `Column(verticalArrangement = spacedBy(SalusSpacing.sm))` (`HomePager.kt:287`).
                VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                    weightRows
                    bloodPressureLine
                    glucoseLine
                }
            } else {
                // `PageEmptyState(MonitorHeart, today_vitals_empty, accent)` (`HomePager.kt:284`).
                SalusEmptyState(
                    systemImage: "waveform.path.ecg",
                    title: HomeStrings.vitalsEmpty,
                    accent: theme.extendedColors.vitals
                )
            }
        }
    }

    /// The weight line and, when there is a trend to draw, the strip under it
    /// (`HomePager.kt:288-299`).
    @ViewBuilder private var weightRows: some View {
        if let weight = vitals.latestWeightKg {
            metricLine(HomeStrings.vitalsWeight(HomeFormatting.number(weight)))
            if vitals.weightTrend.count >= 2 {
                SalusSparkline(
                    values: vitals.weightTrend,
                    lineColor: theme.extendedColors.vitals.accent
                )
                // `fillMaxWidth().height(SalusSpacing.xxl)` (`HomePager.kt:293-295`).
                .frame(maxWidth: .infinity)
                .frame(height: SalusSpacing.xxl)
            }
        }
    }

    /// `today_vitals_bp`, only with both halves (`HomePager.kt:300-308`).
    @ViewBuilder private var bloodPressureLine: some View {
        if let systolic = vitals.latestSystolic, let diastolic = vitals.latestDiastolic {
            metricLine(HomeStrings.vitalsBloodPressure(
                HomeFormatting.number(systolic),
                HomeFormatting.number(diastolic)
            ))
        }
    }

    /// The glucose reading in the unit the user reads in (`HomePager.kt:309-322`).
    @ViewBuilder private var glucoseLine: some View {
        if let mgdl = vitals.latestGlucoseMgdl {
            let glucose = GlucoseConversion.fromMgDl(mgdl, unit: vitals.glucoseUnit)
            metricLine(HomeStrings.vitalsGlucose(HomeFormatting.number(glucose), unit: vitals.glucoseUnit))
        }
    }

    /// `MetricLine(text)` — one reading, `titleMedium` (`HomePager.kt:333-336`).
    private func metricLine(_ text: String) -> some View {
        // `verbatim:` because the caller hands over a resolved string; the plain initializer would
        // treat it as a `LocalizedStringKey` and look it up in the *main* bundle.
        Text(verbatim: text)
            .font(SalusTypography.titleMedium.font)
            .tracking(SalusTypography.titleMedium.tracking)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
