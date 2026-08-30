// Ported from `HomeScreen.kt:273-314` — the next few appointments.
//
// Material → SwiftUI:
//   `Column { … }` per appointment              → a `VStack(alignment: .leading)`.
//   `Spacer(height = sm)` + `align(Alignment.End)` → the same `sm` gap and a trailing-aligned frame
//                                                    around the pill.
//   `DateTimeFormatter.ofLocalizedDateTime(...)`   → `HomeFormatting.appointmentStart(...)`.
//
// The pill's action is the card's action: Kotlin passes the very same `onClick` to both
// (`HomeScreen.kt:306-311`), because "see details" and tapping the card are one intention.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The upcoming appointments (`HomeScreen.kt:273-313`).
struct HomeAppointmentsCard: View {
    let appointments: [UpcomingAppointment]
    let onTap: () -> Void

    var body: some View {
        HomeDashboardCard(onTap: onTap) {
            if appointments.isEmpty {
                HomeEmptyLine(text: HomeStrings.appointmentsEmpty)
            } else {
                ForEach(appointments, id: \.id) { appointment in
                    HomeAppointmentRow(appointment: appointment)
                }
                // `Spacer(height = sm)` then the trailing pill (`HomeScreen.kt:305-311`).
                Spacer().frame(height: SalusSpacing.sm)
                SalusPillButton(text: HomeStrings.viewDetails, tonal: true, action: onTap)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

/// One appointment: who and what, over when (`HomeScreen.kt:287-303`).
private struct HomeAppointmentRow: View {
    let appointment: UpcomingAppointment

    @Environment(\.salusTheme) private var theme
    /// `LocalLocale.current.platformLocale` (`HomeScreen.kt:278`).
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // `listOfNotNull(title, doctorName).joinToString(" · ")` (`HomeScreen.kt:289-290`).
            // Both halves are the user's own text, so nothing here is a catalog key.
            Text(verbatim: [appointment.title, appointment.doctorName].compactMap(\.self).joined(separator: " · "))
                .font(SalusTypography.titleMedium.font)
                .tracking(SalusTypography.titleMedium.tracking)
            Text(verbatim: HomeFormatting.appointmentStart(
                epochMs: appointment.startsAtEpochMs,
                timeZoneId: appointment.timeZoneId,
                locale: locale
            ))
            .font(SalusTypography.bodyMedium.font)
            .tracking(SalusTypography.bodyMedium.tracking)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, SalusSpacing.xs)
    }
}
