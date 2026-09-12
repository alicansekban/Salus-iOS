// Ported from `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/ui/HomePager.kt` —
// `CyclePage` (`:338-370`): where the user is in their cycle.
//
// THE PAGE IS DRAWN ONLY WHEN THE SNAPSHOT EXISTS, and that is the pager's decision, not this
// file's: `HomeSnapshotPager` adds the page only for a non-nil `state.cycle` (`HomePager.kt:81`),
// which `cycleForProfile` leaves nil for a male or missing profile (`TodayModels.kt:10-11`). A
// cycle *snapshot* with no logged period is a different thing, and it is the empty state below.
//
// TWO M15 CHANGES over the pre-M15 card:
//   the platform `ProgressView` is replaced by `SalusProgressBar(tone: .rose)`
//   (`HomePager.kt:356-361`), which paints its own track and closes the divergence that said
//   SwiftUI could not colour one; and the "period ongoing" line becomes a `SalusStatusChip`
//   (`HomePager.kt:362-367`) instead of a tinted sentence.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The cycle snapshot (`CyclePage`, `HomePager.kt:338-370`).
struct HomeCycleCard: View {
    let cycle: CycleSnapshot
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // No interactive child, so the card is the real `Button` `SalusCard(onTap:)` builds
        // (``HomeDashboardCard``'s note). `Favorite` → `heart.fill` (SF Symbol twin).
        HomeSnapshotCard(
            systemImage: "heart.fill",
            accent: theme.extendedColors.cycle,
            title: HomeStrings.cycleTitle,
            onTap: onTap
        ) {
            if let cycleDay = cycle.cycleDay {
                // `Column(verticalArrangement = spacedBy(SalusSpacing.sm))` (`HomePager.kt:351`).
                VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                    day(cycleDay)
                    progress(for: cycleDay)
                    periodOngoing
                }
            } else {
                // `PageEmptyState(Favorite, today_cycle_empty, accent)` (`HomePager.kt:348`).
                SalusEmptyState(
                    systemImage: "heart.fill",
                    title: HomeStrings.cycleEmpty,
                    accent: theme.extendedColors.cycle
                )
            }
        }
    }

    /// `stringResource(R.string.today_cycle_day, cycle.cycleDay)` (`HomePager.kt:352-355`).
    private func day(_ cycleDay: Int) -> some View {
        // `verbatim:` because the string is already resolved; the plain initializer would treat it
        // as a `LocalizedStringKey` and look it up in the *main* bundle.
        Text(verbatim: HomeStrings.cycleDay(cycleDay))
            .font(SalusTypography.titleMedium.font)
            .tracking(SalusTypography.titleMedium.tracking)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `averageCycleLengthDays?.takeIf { it > 0 }?.let { … }` (`HomePager.kt:356-361`) — no bar
    /// without a length to measure against, and a zero length would divide by nothing.
    @ViewBuilder private func progress(for cycleDay: Int) -> some View {
        if let length = cycle.averageCycleLengthDays, length > 0 {
            // `(cycleDay.toFloat() / length.toFloat()).coerceIn(0f, 1f)` (`HomePager.kt:358`).
            SalusProgressBar(progress: min(max(Double(cycleDay) / Double(length), 0), 1), tone: .rose)
        }
    }

    /// `if (cycle.isPeriodOpen) SalusStatusChip(today_cycle_period_ongoing, Accent)`
    /// (`HomePager.kt:362-367`).
    @ViewBuilder private var periodOngoing: some View {
        if cycle.isPeriodOpen {
            SalusStatusChip(label: HomeStrings.cyclePeriodOngoing, status: .accent)
        }
    }
}
