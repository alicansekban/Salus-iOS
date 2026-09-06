// Ported from `HomeScreen.kt:350-510` — the latest weight, blood pressure and glucose, each as a
// badge + `titleMedium` value row (the M12 stat-tile reshape).
//
// Three conditions, all Kotlin's:
//   `hasAnything`                       — nothing recorded at all is one empty line and no rows
//                                         (`HomeScreen.kt:440-445`).
//   `weightTrend.size >= 2`             — the sparkline needs two points to be a line
//                                         (`HomeScreen.kt:459`); `SalusSparkline` draws nothing
//                                         below that either, but the guard stays where Kotlin
//                                         has it so the 96×32 slot is not reserved for a blank.
//   `systolic != null && diastolic != null` — one half of a reading is not a reading
//                                         (`HomeScreen.kt:468`).
//
// The glucose line is the one place the port does arithmetic Kotlin spells inline: the snapshot
// always carries mg/dL, and `GlucoseConversion.fromMgDl(_:unit:)` is the twin of
// `mgdl / GlucoseConversion.MG_DL_PER_MMOL_L` (`HomeScreen.kt:487-501`) — with the mg/dL arm the
// identity, exactly as the Kotlin `when` leaves it unconverted. Untouched by this milestone.
//
// Every row leads with `SalusIconBadge(MonitorHeart, vitals)` and the value is `titleMedium`
// (`HomeScreen.kt:447-508`); `MonitorHeart` → `waveform.path.ecg` (SF Symbol twin, iOS 17 — a 60 Hz
// heart trace, the closest family symbol to Material's monitor-heart). The weight row keeps the
// sparkline trailing; the two rows below have no trailing child, so their text stays greedy.
//
// The sparkline is `.accessibilityHidden(true)` inside `SalusSparkline` itself: the weight beside
// it is already spoken, and Compose gives its `Canvas` no `contentDescription` either.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// The vitals snapshot (`HomeScreen.kt:437-509`).
struct HomeVitalsCard: View {
    let vitals: VitalsSnapshot
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme

    /// `hasAnything` (`HomeScreen.kt:440-441`).
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

    /// The weight row: badge, `titleMedium` value, and the sparkline when there is a trend to draw
    /// (`HomeScreen.kt:447-467`).
    @ViewBuilder private var weightRow: some View {
        if let weight = vitals.latestWeightKg {
            HStack(spacing: 0) {
                rowBadge
                Spacer().frame(width: SalusSpacing.md)
                value(HomeStrings.vitalsWeight(HomeFormatting.number(weight)))
                if vitals.weightTrend.count >= 2 {
                    SalusSparkline(
                        values: vitals.weightTrend,
                        lineColor: theme.extendedColors.vitals.accent
                    )
                    .frame(width: HomeFormatting.sparklineWidth, height: HomeFormatting.sparklineHeight)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// `today_vitals_bp`, only with both halves (`HomeScreen.kt:468-485`).
    @ViewBuilder private var bloodPressureLine: some View {
        if let systolic = vitals.latestSystolic, let diastolic = vitals.latestDiastolic {
            HStack(spacing: 0) {
                rowBadge
                Spacer().frame(width: SalusSpacing.md)
                value(HomeStrings.vitalsBloodPressure(
                    HomeFormatting.number(systolic),
                    HomeFormatting.number(diastolic)
                ))
            }
            .padding(.top, SalusSpacing.xs)
        }
    }

    /// The glucose reading in the unit the user reads in (`HomeScreen.kt:486-508`).
    @ViewBuilder private var glucoseLine: some View {
        if let mgdl = vitals.latestGlucoseMgdl {
            let glucose = GlucoseConversion.fromMgDl(mgdl, unit: vitals.glucoseUnit)
            HStack(spacing: 0) {
                rowBadge
                Spacer().frame(width: SalusSpacing.md)
                value(HomeStrings.vitalsGlucose(HomeFormatting.number(glucose), unit: vitals.glucoseUnit))
            }
            .padding(.top, SalusSpacing.xs)
        }
    }

    /// `SalusIconBadge(MonitorHeart, vitals)` (`HomeScreen.kt:449-452`, `:471-474`, `:489-492`).
    /// Repeated per row rather than shared so each row is self-contained, exactly as Kotlin calls
    /// the composable once per row.
    private var rowBadge: some View {
        SalusIconBadge(systemImage: "waveform.path.ecg", accent: theme.extendedColors.vitals)
    }

    /// The value text: `titleMedium`, `weight(1f)` (`HomeScreen.kt:454-458`, `:476-483`,
    /// `:503-506`) — greedy so the weight sparkline is pushed to the trailing edge and the two
    /// lines below start at the same inset.
    private func value(_ text: String) -> some View {
        // `verbatim:` because the caller hands over a resolved string; the plain initializer would
        // treat it as a `LocalizedStringKey` and look it up in the *main* bundle.
        Text(verbatim: text)
            .font(SalusTypography.titleMedium.font)
            .tracking(SalusTypography.titleMedium.tracking)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
