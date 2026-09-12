// Ported from `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/ui/HomePager.kt` —
// `DosesPage` (`:173-236`), `LastDoseRow` (`:238-259`), `DoseStatusChip` (`:261-270`) and the
// `lastSettled()` helper (`:372-374`). The M15 page is the day's dose ring beside one sentence
// about what is next, the last settled dose under it, and a single action — not the scrolling list
// of every slot the pre-M15 card drew, which a fixed-height pager page has no room for.
//
// THE "NEXT DOSE" IS DERIVED HERE, and that is the one shape difference from Kotlin. Android added
// `HomeUiState.nextDose` and computes it in the ViewModel "so the snapshot card never re-scans the
// list on every recomposition" (`HomeUiState.kt:45-50`); spec §4.1 records **no UiState change**
// for iOS, so the same rule — the earliest `.pending` entry of `doses` — is applied to the list the
// state already carries. It reads the same data and answers the same dose; nothing new is observed,
// stored or passed across a layer.
//
// Material → SwiftUI:
//   `Row(verticalAlignment = CenterVertically, spacedBy(lg))` → `HStack(spacing: SalusSpacing.lg)`.
//   `Column(weight(1f), spacedBy(sm))`                → `VStack(spacing: sm)` on a greedy frame.
//   `Modifier.align(Alignment.End)`                   → a trailing-aligned greedy frame.
//   `SalusEmptyState(icon, title, accent)`            → the same component, SF Symbol for the icon.
//
// THE CARD IS NOT A BUTTON HERE, AND KOTLIN'S IS. Compose dispatches a tap to the innermost
// clickable, so `SalusCard(onClick = …)` with a `SalusButton` inside it works there. On iOS
// `SalusCard(onTap:)` is `Button(action:) { surface }` (`SalusCard.swift:64-76`), and a `Button`
// inside another `Button`'s label is treated as decoration: the outer one swallows the tap, so
// "Alındı" would switch tabs and never record the dose. Three shipped features settled the shape —
// `VitalsRow` first, then `MedicationCard` and `AppointmentCard` — and this page keeps it: a
// non-interactive ``HomeSnapshotCard``, the "open medications" tap on the ring-and-text block
// through `homeOpensCard(_:)`, and the pill as that block's **sibling**. The two targets are then
// disjoint by layout rather than merely ordered by dispatch rules.
//
// DIVERGENCE (c), THE RING'S COLOUR. Kotlin tints the ring with the medications accent
// (`progressColor = accent.accent`, `HomePager.kt:201`); `SalusProgressRing` takes `progress`,
// `label`, `size` and `strokeWidth` and draws `primary` (`SalusProgressRing.swift:51-56`). Adding a
// colour to a shared component is `SalusUI`'s change, not this screen's, so the ring stays
// `primary` here and the accent is carried by the badge, the time and the action beside it.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// Today's doses at a glance (`DosesPage`, `HomePager.kt:172-236`).
struct HomeDosesCard: View {
    let doses: [TodayDose]
    let doseProgress: (taken: Int, total: Int)?
    let onEvent: (HomeEvent) -> Void
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme
    /// `LocalLocale.current.platformLocale` (`HomePager.kt:182`).
    @Environment(\.locale) private var locale

    /// `HomeUiState.nextDose` (`HomeUiState.kt:45-50`), whose rule is
    /// `doses.filter { it.status == PENDING }.minByOrNull { it.minuteOfDay }`
    /// (`HomeViewModel.kt:143-144`) — applied here rather than in the ViewModel, see the file
    /// header. `minByOrNull` orders explicitly because the repository promises a list of today's
    /// slots, not an ordered one (`HomeViewModel.kt:139-142`).
    private var nextDose: TodayDose? {
        doses.filter { $0.status == .pending }.min { $0.minuteOfDay < $1.minuteOfDay }
    }

    /// `List<TodayDose>.lastSettled()` (`HomePager.kt:372-374`): the latest dose of the day that is
    /// no longer waiting on the user — what was taken, snoozed or missed, so the ring's number has
    /// a story behind it (`HomePager.kt:220-221`).
    private var lastSettled: TodayDose? {
        doses.filter { $0.status != .pending }.max { $0.minuteOfDay < $1.minuteOfDay }
    }

    var body: some View {
        HomeSnapshotCard(
            systemImage: "pills.fill",
            accent: theme.extendedColors.medications,
            title: HomeStrings.dosesTitle
        ) {
            if doses.isEmpty {
                // `PageEmptyState(Medication, today_doses_empty, accent)` (`HomePager.kt:189-192`).
                // `Medication` → `pills.fill` (SF Symbol twin).
                SalusEmptyState(
                    systemImage: "pills.fill",
                    title: HomeStrings.dosesEmpty,
                    accent: theme.extendedColors.medications
                )
                .homeOpensCard(onTap)
            } else {
                summary
                takeAction
            }
        }
    }

    /// The ring and the two lines beside it (`HomePager.kt:193-224`).
    private var summary: some View {
        HStack(spacing: SalusSpacing.lg) {
            if let doseProgress {
                // `SalusProgressRing(progress = taken.toFloat() / total, label = "$taken/$total")`
                // (`HomePager.kt:198-202`). The label is two numbers, never a catalog key.
                SalusProgressRing(
                    progress: Float(doseProgress.taken) / Float(doseProgress.total),
                    label: "\(doseProgress.taken)/\(doseProgress.total)"
                )
            }
            VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                Text(verbatim: nextDoseText)
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let lastSettled {
                    HomeLastDoseRow(dose: lastSettled)
                }
            }
            // `Modifier.weight(1f)` (`HomePager.kt:205`).
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .homeOpensCard(onTap)
    }

    /// `if (nextDose == null) home_next_dose_none else home_next_dose(name, time)`
    /// (`HomePager.kt:209-217`).
    private var nextDoseText: String {
        guard let nextDose else { return HomeStrings.nextDoseNone }
        return HomeStrings.nextDose(
            // The medication's own name, never a catalog key.
            nextDose.medicationName,
            HomeFormatting.minutes(nextDose.minuteOfDay, locale: locale)
        )
    }

    /// `if (nextDose != null) { Spacer(md); SalusButton(home_take_dose, align(End), Medium, accent) }`
    /// (`HomePager.kt:225-234`).
    @ViewBuilder private var takeAction: some View {
        if let nextDose {
            Spacer().frame(height: SalusSpacing.md)
            SalusButton(
                HomeStrings.takeDose,
                size: .medium,
                accent: theme.extendedColors.medications
            ) {
                onEvent(.takeDose(scheduleId: nextDose.scheduleId, minuteOfDay: nextDose.minuteOfDay))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

/// The last settled dose: the overline, then the time, the name and the status chip
/// (`LastDoseRow`, `HomePager.kt:238-259`).
private struct HomeLastDoseRow: View {
    let dose: TodayDose

    @Environment(\.salusTheme) private var theme
    /// `LocalLocale.current.platformLocale` (`HomePager.kt:239`).
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            // `home_last_dose` is stored upper-case in the catalog (spec §6) — never
            // `uppercased()` at runtime, which a Turkish locale would spell with a dotted İ.
            Text(verbatim: HomeStrings.lastDose)
                .font(SalusTypography.labelSmall.font)
                .tracking(SalusTypography.labelSmall.tracking)
                .foregroundStyle(theme.extendedColors.overline)
            // `Row(verticalAlignment = CenterVertically, spacedBy(sm))` (`HomePager.kt:246-257`).
            HStack(spacing: SalusSpacing.sm) {
                // `"${formatMinutes(minuteOfDay, locale)} · ${medicationName}"`
                // (`HomePager.kt:251`) — a time and the user's own text, so nothing is a key.
                Text(verbatim: "\(HomeFormatting.minutes(dose.minuteOfDay, locale: locale)) · \(dose.medicationName)")
                    .font(SalusTypography.bodySmall.font)
                    .tracking(SalusTypography.bodySmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                // `Modifier.weight(1f, fill = false)` (`HomePager.kt:254`) is "take what you need,
                // do not expand", which is a plain `Text`'s own behaviour here — the greedy frame
                // is on the row below, not on the line, so a short name leaves the chip beside it
                // instead of pushing it to the edge.
                SalusStatusChip(label: HomeStrings.doseStatus(dose.status), status: Self.chipStatus(dose.status))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// `DoseStatusChip`'s table (`HomePager.kt:262-270`). The label half of that `when` lives in
    /// `HomeStrings.doseStatus(_:)`, so only the tint is decided here.
    private static func chipStatus(_ status: DoseStatus) -> SalusStatus {
        switch status {
        case .taken: .success
        case .snoozed: .warning
        case .pending: .neutral
        case .missed: .error
        }
    }
}
