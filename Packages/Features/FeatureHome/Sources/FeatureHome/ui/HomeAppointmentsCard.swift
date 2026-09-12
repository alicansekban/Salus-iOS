// Ported from `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/ui/HomeCards.kt` —
// `AppointmentsSection` (`:108-150`) and `AppointmentCard` (`:152-196`).
//
// THE M15 SHAPE IS ONE CARD PER APPOINTMENT, not one card holding every row: a card names one
// appointment, so it is the thing that opens it (parity row A58). The section header carries the
// "Tümünü Gör" action that opens the tab, and an empty list is a single card holding the shared
// empty state (`HomeCards.kt:132-139`).
//
// The file keeps its name while holding the section, because the section is nothing but its cards:
// ``HomeAppointmentsSection`` is the header plus the list, and the card itself is `private` here
// the way Kotlin keeps `AppointmentCard` private inside `HomeCards.kt`.
//
// DIVERGENCE (e), WHERE A CARD GOES. Kotlin takes `onOpenAppointment: (String) -> Unit` and opens
// that appointment's own detail screen (`HomeCards.kt:144`); Home does not own that key, so on
// Android it is a shell callback. iOS's shell hands Home five callbacks and `onOpenAppointments` is
// the one for this section (spec §4.1 leaves the callback contract alone in this task), so a card
// opens the Appointments tab rather than the appointment. The per-id jump needs a shell change and
// is not this task's.
//
// Material → SwiftUI:
//   `Column(verticalArrangement = spacedBy(sm))`  → `VStack(spacing: SalusSpacing.sm)`.
//   `SalusSectionHeader(action =, onAction =)`    → the header's `actions:` `@ViewBuilder` slot.
//   `startsAt.format(dateFormatter(locale))`      → `HomeFormatting.appointmentDate(...)`.
//   `startsAt.format(timeFormatter(locale))`      → `HomeFormatting.appointmentTime(...)`.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The next few appointments: a section header that opens the tab, then one card each
/// (`AppointmentsSection`, `HomeCards.kt:108-150`).
struct HomeAppointmentsSection: View {
    let appointments: [UpcomingAppointment]
    let onOpenAppointments: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.sm) {
            // `today_appointments_title` is stored upper-case in the catalog (spec §6) — never
            // `uppercased()` at runtime, which a Turkish locale would spell with a dotted İ.
            SalusSectionHeader(title: HomeStrings.appointmentsTitle) {
                seeAllAction
            }
            if appointments.isEmpty {
                // `SalusCard { SalusEmptyState(CalendarMonth, today_appointments_empty, accent) }`
                // (`HomeCards.kt:133-139`). `CalendarMonth` → `calendar` (SF Symbol twin).
                HomeDashboardCard {
                    SalusEmptyState(
                        systemImage: "calendar",
                        title: HomeStrings.appointmentsEmpty,
                        accent: theme.extendedColors.appointments
                    )
                }
            } else {
                ForEach(appointments, id: \.id) { appointment in
                    HomeAppointmentCard(appointment: appointment, onTap: onOpenAppointments)
                }
            }
        }
    }

    /// The header's trailing text action: `labelLarge` in `primary`, on a full-height touch target
    /// (`SalusSectionHeader.kt:59-73`). The shape this section used to spell out itself now lives
    /// in ``SalusSectionHeaderAction``, so every header action in the tree is the same view.
    private var seeAllAction: some View {
        SalusSectionHeaderAction(title: HomeStrings.seeAll, action: onOpenAppointments)
    }
}

/// One appointment: who and what, over when (`AppointmentCard`, `HomeCards.kt:152-196`).
///
/// The card holds no interactive child, so it can be the real `Button` `SalusCard(onTap:)` builds —
/// free button semantics, free VoiceOver (``HomeDashboardCard``'s note). The M15 card lost the
/// "Detayları gör" pill that used to force the non-interactive shape.
private struct HomeAppointmentCard: View {
    let appointment: UpcomingAppointment
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme
    /// `LocalLocale.current.platformLocale` (`HomeCards.kt:158`).
    @Environment(\.locale) private var locale

    var body: some View {
        HomeDashboardCard(onTap: onTap) {
            // `Row(verticalAlignment = CenterVertically, spacedBy(md))` (`HomeCards.kt:164-194`).
            HStack(spacing: SalusSpacing.md) {
                SalusAvatar(name: appointment.doctorName)
                // `Column(weight(1f), spacedBy(xs))` (`HomeCards.kt:169-189`).
                VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                    // The user's own text, so nothing here is a catalog key.
                    Text(verbatim: appointment.title)
                        .font(SalusTypography.titleMedium.font)
                        .tracking(SalusTypography.titleMedium.tracking)
                    if let doctorName = appointment.doctorName {
                        // `listOfNotNull(doctorName, location).joinToString(" · ")`
                        // (`HomeCards.kt:161-162`); iOS's `UpcomingAppointment` carries no
                        // `location`, so the secondary line is the doctor alone.
                        secondary(doctorName)
                    }
                    secondary(HomeFormatting.appointmentDate(
                        epochMs: appointment.startsAtEpochMs,
                        timeZoneId: appointment.timeZoneId,
                        locale: locale
                    ))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // `SalusStatusChip(startsAt.format(timeFormatter), Accent)` (`HomeCards.kt:190-193`).
                SalusStatusChip(
                    label: HomeFormatting.appointmentTime(
                        epochMs: appointment.startsAtEpochMs,
                        timeZoneId: appointment.timeZoneId,
                        locale: locale
                    ),
                    status: .accent
                )
            }
        }
    }

    /// A supporting line: `bodySmall` on `onSurfaceVariant` (`HomeCards.kt:177-188`).
    private func secondary(_ text: String) -> some View {
        Text(verbatim: text)
            .font(SalusTypography.bodySmall.font)
            .tracking(SalusTypography.bodySmall.tracking)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
    }
}
