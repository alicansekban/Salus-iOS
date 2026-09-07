// Ported from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/appointments/
// ui/list/AppointmentsScreen.kt:241-299` (`AppointmentCard` and `DetailRow`). Split into its own
// file the way M4 split Medications' row into `MedicationCard.swift`: the screen file stays the
// screen's shape — header, the three content states, the agenda and the confirmation — and
// splitting the rows out is what brought `AppointmentsScreen.swift` back under the 500-line cap.
//
// ONE SHAPE THE KOTLIN DOES NOT NEED. The row's trash icon: `SalusCard(onTap:)` is a `Button`, so a
// second `Button` inside its label is treated as decoration and the outer button swallows the tap.
// `VitalsRow` (`VitalsScreen.swift:258-307`) settled this, and this row copies its answer: a plain,
// non-interactive `SalusCard`, "open" as a tap gesture on the text column with the button semantics
// added back by hand, and the trash as a real `Button` that is the column's **sibling**, so the two
// targets are disjoint by layout rather than merely ordered by dispatch rules.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Date tile on the left, time and what/where on the right, the trash on the far right
/// (`AppointmentsScreen.kt:241-286`).
///
/// See the file header for why the card is not `SalusCard(onTap:)` with the button inside it.
struct AppointmentCard: View {
    let item: AppointmentListItem
    let onTap: () -> Void
    let onDelete: () -> Void

    @Environment(\.salusTheme) private var theme
    /// The in-app language pick (`RootView+Locale.swift`), not `Locale.current`, which on iOS keeps
    /// answering with the device's language whatever the in-app setting says.
    @Environment(\.locale) private var locale

    var body: some View {
        SalusCard {
            HStack(alignment: .top, spacing: 0) {
                details
                    // The column already fills every point the trash button does not, and
                    // `contentShape` makes the empty space beside a short title tappable too.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTap)
                    // A tap gesture is invisible to VoiceOver, where Compose's `SalusCard(onClick =)`
                    // is announced as a button. `.combine` reads the row's lines as one element, the
                    // trait announces it as activatable, and the action is what a double tap runs.
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction(.default, onTap)

                // `Spacer(width = sm)` + `IconButton` (`AppointmentsScreen.kt:276-283`). A sibling
                // of the column, not a descendant of any Button.
                Button(action: onDelete) {
                    Label(AppointmentsStrings.delete, systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(theme.colorScheme.error)
                }
                .buttonStyle(.plain)
                .padding(.leading, SalusSpacing.sm)
            }
        }
        .padding(.horizontal, SalusSpacing.lg)
    }

    /// The date tile and the text column — everything a tap on the row opens
    /// (`AppointmentsScreen.kt:259-275`).
    private var details: some View {
        HStack(alignment: .top, spacing: 0) {
            SalusDateTile(
                dayOfMonth: item.startsAt.date.day,
                monthShort: item.startsAt.formatted(pattern: monthPattern, locale: locale),
                accent: theme.extendedColors.appointments
            )

            // `Spacer(width = md)` between the tile and the content column
            // (`AppointmentsScreen.kt:265`).
            Spacer().frame(width: SalusSpacing.md)

            VStack(alignment: .leading, spacing: 0) {
                // The time sits directly above the title, in the accent's accent colour
                // (`AppointmentsScreen.kt:267-271`).
                Text(verbatim: item.startsAt.formatted(pattern: timePattern, locale: locale))
                    .font(SalusTypography.labelLarge.font)
                    .tracking(SalusTypography.labelLarge.tracking)
                    .foregroundStyle(theme.extendedColors.appointments.accent)
                Text(verbatim: item.title)
                    .font(SalusTypography.titleMedium.font)
                    .foregroundStyle(theme.colorScheme.onSurface)
                if let doctorName = item.doctorName {
                    DetailRow(systemImage: "person", text: doctorName)
                }
                if let location = item.location {
                    DetailRow(systemImage: "mappin.and.ellipse", text: location)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// `AppointmentsScreen.kt:280-299`.
private struct DetailRow: View {
    let systemImage: String
    let text: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        HStack(spacing: SalusSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: detailIconSize))
                // Decoration: the text beside it already says what this is
                // (`contentDescription = null`).
                .accessibilityHidden(true)
            Text(verbatim: text)
                .font(SalusTypography.bodyMedium.font)
        }
        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
        .padding(.top, SalusSpacing.xs)
    }
}

/// `AppointmentsScreen.kt:249`.
private let timePattern = "HH:mm"
/// `AppointmentsScreen.kt:250`.
private let monthPattern = "MMM"
/// `AppointmentsScreen.kt:301`.
private let detailIconSize: CGFloat = 16
