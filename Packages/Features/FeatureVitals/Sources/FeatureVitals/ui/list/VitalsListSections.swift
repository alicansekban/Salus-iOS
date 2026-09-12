// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/list/VitalsScreen.kt:126-248` — the loading/empty/list branch and the `LazyColumn` that draws
// the chart section, the chart card, the statistics row, the history header and the rows.
//
// Kotlin keeps all of it in one file because a `private @Composable` is invisible outside it; Swift
// has no per-file privacy for a `View` used from another file, so the row, the chart card and the
// formatters are `VitalsRow.swift`, `VitalsChartCard.swift` and `VitalsFormatting.swift` — internal
// types nothing outside this package can name, since the package exports the Routes and nothing
// else.
//
// Material → SwiftUI, M15 shapes:
//   `LazyColumn`              → `ScrollView` + `LazyVStack`.
//   `SalusSectionHeader(action:onAction:)` → the same component, whose trailing slot is a `Button`.
//   `CircularProgressIndicator` → `ProgressView()`.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// `VitalsScreen.kt:126-150` — the loading spinner, the empty state, or the list.
struct VitalsListContent: View {
    let state: VitalsUiState
    let onEvent: (VitalsEvent) -> Void
    let onAddEntry: (VitalType) -> Void
    let onEditEntry: (VitalsListItem) -> Void
    let onOpenTrends: () -> Void

    @Environment(\.salusTheme) private var theme

    /// §10: reduce motion keeps the fade and drops the move, on both platforms.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if state.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.entries.isEmpty {
            SalusEmptyState(
                systemImage: "heart.text.square",
                title: emptyTitle,
                accent: theme.extendedColors.vitals,
                actionLabel: VitalsStrings.addEntry,
                onAction: { onAddEntry(state.selectedType) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            entryList
        }
    }

    /// `VitalsScreen.kt:177-248`.
    private var entryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SalusSpacing.md) {
                if state.chart != nil {
                    chartSectionHeader
                }

                // Drawn whether or not there is a line to draw: the card also carries the latest
                // reading and the range filter, and both stay reachable below the two points a
                // chart needs (`VitalsScreen.kt:215-220`).
                VitalsChartCard(state: state, onEvent: onEvent)

                // The summary describes exactly what the chart draws, so the two can never
                // disagree. The chart is nil below two points, which is also where a
                // highest/average/lowest row would be restating a single reading three times
                // (`VitalsScreen.kt:184-189`).
                if let stats {
                    VitalsStatsRow(state: state, stats: stats)
                }

                SalusSectionHeader(
                    title: VitalsStrings.historySection,
                    contentPadding: SalusSectionHeaderDefaults.topOnly
                )

                ForEach(state.entries) { entry in
                    VitalsRow(
                        entry: entry,
                        onEdit: { onEditEntry(entry) },
                        onDelete: { onEvent(.deleteRequested(entry.id)) }
                    )
                    // §10 list mutation: fade + vertical move on add, remove and undo's return.
                    // Reduce motion keeps the fade and drops the move (`VitalsScreen.kt:240-244`).
                    .transition(
                        reduceMotion
                            ? SalusMotion.listMutationReducedMotionTransition
                            : SalusMotion.listMutationTransition
                    )
                }
            }
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.top, SalusSpacing.xs)
            // Keeps the last row scrollable above the floating action button
            // (`VitalsScreen.kt:373-375`).
            .padding(.bottom, VitalsListDefaults.fabClearance)
            // Every mutation path — delete confirmed, undo's return, an editor save landing —
            // arrives as a state change the container observes, so the animation rides with it
            // wherever it came from.
            .animation(
                reduceMotion
                    ? SalusMotion.listMutationReducedMotionAnimation
                    : SalusMotion.listMutationAnimation,
                value: state.entries
            )
        }
    }

    /// `metricStatsOf(chart.points.map { it.y })` (`VitalsScreen.kt:187-188`) — a property rather
    /// than a clause inside the `LazyVStack`, so the builder stays one expression per row.
    private var stats: MetricStats? {
        state.chart.flatMap { metricStatsOf($0.points.map { Double($0.y) }) }
    }

    /// `VitalsScreen.kt:201-213` — the "GRAFİK" overline with the trends link in its trailing slot.
    ///
    /// Trends live in another feature, so the tap is a callback the shell fills in. Deliberately
    /// ungated: a free user reaches the screen and meets its own lock.
    private var chartSectionHeader: some View {
        SalusSectionHeader(
            title: VitalsStrings.chartSection,
            contentPadding: SalusSectionHeaderDefaults.topOnly
        ) {
            Button(action: onOpenTrends) {
                Text(verbatim: VitalsStrings.openTrends)
                    .font(SalusTypography.labelLarge.font)
            }
            .tint(theme.colorScheme.primary)
        }
    }

    /// `emptyTitle` (`VitalsScreen.kt:364-369`).
    private var emptyTitle: String {
        switch state.selectedType {
        case .weight: VitalsStrings.empty
        case .bloodPressure: VitalsStrings.emptyBloodPressure
        case .bloodGlucose: VitalsStrings.emptyGlucose
        }
    }
}

/// Component dimensions, not design tokens (`VitalsScreen.kt:373-375`).
enum VitalsListDefaults {
    /// Keeps the last row scrollable above the floating action button. Android adds the floating
    /// bottom bar's clearance on top; the iOS tab bar is the system's and already inset.
    static let fabClearance: CGFloat = 88
}
