// Ported from `HomeScreen.kt:215-271` — the first card, and the only one with an action inside it.
//
// Material → SwiftUI:
//   `Row(verticalAlignment = CenterVertically)` → `HStack` (its default alignment is `.center`).
//   `Spacer(width = md)` + `Modifier.weight(1f)` → a leading `padding` on a greedy `frame`, which
//                                                  is the same drawn result: fixed time column,
//                                                  `md` gap, name filling what is left.
//   `SalusPillButton(tonal = true, accent = …)`  → `SalusUI.SalusPillButton`, argument for argument.
//
// The card is tappable *and* carries a button per pending row. That is Kotlin's shape too
// (`SalusCard(onClick = …)` wrapping `SalusPillButton(onClick = …)`); SwiftUI resolves the inner
// button first, so a tap on "Al" records the dose and does not also switch tabs.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// Today's dose slots (`HomeScreen.kt:215-260`).
struct HomeDosesCard: View {
    let doses: [TodayDose]
    let onEvent: (HomeEvent) -> Void
    let onTap: () -> Void

    var body: some View {
        HomeDashboardCard(onTap: onTap) {
            if doses.isEmpty {
                HomeEmptyLine(text: HomeStrings.dosesEmpty)
            } else {
                // `id: \.self` — the whole dose. One schedule has several slots a day, so the
                // schedule id alone is not unique within this list; `TodayDose` is `Hashable`
                // precisely so the row can be identified by everything it draws.
                ForEach(doses, id: \.self) { dose in
                    HomeDoseRow(dose: dose, onEvent: onEvent)
                }
            }
        }
    }
}

/// One dose slot: time, name and either the take button or the status chip
/// (`HomeScreen.kt:227-256`).
private struct HomeDoseRow: View {
    let dose: TodayDose
    let onEvent: (HomeEvent) -> Void

    @Environment(\.salusTheme) private var theme
    /// `LocalLocale.current.platformLocale` (`HomeScreen.kt:221`).
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 0) {
            Text(verbatim: HomeFormatting.minutes(dose.minuteOfDay, locale: locale))
                .font(SalusTypography.labelLarge.font)
                .tracking(SalusTypography.labelLarge.tracking)
                .foregroundStyle(theme.extendedColors.medications.accent)
            // The medication's own name, never a catalog key.
            Text(verbatim: dose.medicationName)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, SalusSpacing.md)
            trailing
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SalusSpacing.xs)
    }

    /// `if (dose.status == PENDING) SalusPillButton(...) else DoseStatusChip(...)`
    /// (`HomeScreen.kt:244-255`).
    @ViewBuilder private var trailing: some View {
        if dose.status == .pending {
            SalusPillButton(
                text: HomeStrings.takeDose,
                tonal: true,
                accent: theme.extendedColors.medications
            ) {
                onEvent(.takeDose(scheduleId: dose.scheduleId, minuteOfDay: dose.minuteOfDay))
            }
        } else {
            SalusStatusChip(label: HomeStrings.doseStatus(dose.status), status: Self.chipStatus(dose.status))
        }
    }

    /// `DoseStatusChip`'s table (`HomeScreen.kt:264-269`). The label half of that `when` lives in
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
