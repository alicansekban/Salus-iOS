// Ported from `HomeScreen.kt:316-348` — where the user is in their cycle.
//
// THE CARD IS DRAWN FOR EVERY USER (plan ruling 9). Android gates it on nothing — no sex, no
// profile field, no setting (research §1, row 7: "**no sex gate**") — and the port keeps that
// exactly, because the gate would be a product decision this milestone is not making.
//
// DIVERGENCE (i), THE PROGRESS TRACK. `LinearProgressIndicator(progress:, color:, trackColor:)`
// (`HomeScreen.kt:328-335`) colours bar and track in one call; SwiftUI's `ProgressView(value:)`
// takes a tint and nothing else. The accent is therefore carried by `.tint` and the track is the
// platform's own dimmed rendering of it rather than `cycle.container` — the way
// `MedicationCard.swift:14-19` already settled this same gap. Drawing the track by hand (a
// `Capsule` behind the bar, say) would give the token back and cost the platform's sizing,
// animation and accessibility, for a 4 pt strip; the bar's *value* is what the card is saying.

import SalusDesignSystem
import SwiftUI

/// The cycle snapshot (`HomeScreen.kt:317-347`).
struct HomeCycleCard: View {
    let cycle: CycleSnapshot
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        HomeDashboardCard(onTap: onTap) {
            if let cycleDay = cycle.cycleDay {
                day(cycleDay)
                progress(for: cycleDay)
                periodOngoing
            } else {
                HomeEmptyLine(text: HomeStrings.cycleEmpty)
            }
        }
    }

    /// `stringResource(R.string.today_cycle_day, cycle.cycleDay)` (`HomeScreen.kt:322-325`).
    private func day(_ cycleDay: Int) -> some View {
        Text(verbatim: HomeStrings.cycleDay(cycleDay))
            .font(SalusTypography.titleMedium.font)
            .tracking(SalusTypography.titleMedium.tracking)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `averageCycleLengthDays?.takeIf { it > 0 }?.let { … }` (`HomeScreen.kt:326-336`) — no bar
    /// without a length to measure against, and a zero length would divide by nothing.
    @ViewBuilder private func progress(for cycleDay: Int) -> some View {
        if let length = cycle.averageCycleLengthDays, length > 0 {
            // `Spacer(height = sm)` (`HomeScreen.kt:327`).
            Spacer().frame(height: SalusSpacing.sm)
            // `(cycleDay.toFloat() / length.toFloat()).coerceIn(0f, 1f)` (`HomeScreen.kt:330`).
            ProgressView(value: min(max(Double(cycleDay) / Double(length), 0), 1))
                .progressViewStyle(.linear)
                .tint(theme.extendedColors.cycle.accent)
        }
    }

    /// `if (cycle.isPeriodOpen) { … }` (`HomeScreen.kt:337-344`).
    @ViewBuilder private var periodOngoing: some View {
        if cycle.isPeriodOpen {
            Spacer().frame(height: SalusSpacing.sm)
            Text(verbatim: HomeStrings.cyclePeriodOngoing)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(theme.extendedColors.cycle.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
