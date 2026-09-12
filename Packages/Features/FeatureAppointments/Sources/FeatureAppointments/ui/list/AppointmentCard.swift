// Ported from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/appointments/
// ui/list/AppointmentCard.kt`.
//
// ONE SHAPE THE KOTLIN DOES NOT NEED. The row's trash icon: `SalusCard(onTap:)` is a `Button`, so a
// second `Button` inside its label is treated as decoration and the outer button swallows the tap.
// `VitalsRow` (`VitalsScreen.swift:258-307`) settled this, and this row copies its answer: a plain,
// non-interactive `SalusCard`, "open" as a tap gesture on the text column with the button semantics
// added back by hand, and the trash as a real `Button` that is the column's **sibling**, so the two
// targets are disjoint by layout rather than merely ordered by dispatch rules. The M15 row's trash
// is `SalusIconButton(.destructive)` (`AppointmentCard.kt:95-100`).

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// One appointment, shared by both tabs: the date tile on the left, what and where in the middle,
/// and the chips that say when it starts and when it will be announced underneath
/// (`AppointmentCard.kt:45-51`).
///
/// The whole card opens the detail screen; the trash icon only asks for a confirmation, so a
/// mistaken tap on a row costs a dialog rather than an appointment.
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
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    details
                        // The column already fills every point the trash button does not, and
                        // `contentShape` makes the empty space beside a short title tappable too.
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onTap)
                        // A tap gesture is invisible to VoiceOver, where Compose's
                        // `SalusCard(onClick =)` is announced as a button. `.combine` reads the
                        // row's lines as one element, the trait announces it as activatable, and
                        // the action is what a double tap runs.
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction(.default, onTap)

                    // `Spacer(width = sm)` + `IconButton` (`AppointmentCard.kt:94-100`). A sibling
                    // of the column, not a descendant of any Button.
                    SalusIconButton(
                        systemImage: "trash",
                        accessibilityLabel: AppointmentsStrings.delete,
                        tone: .destructive,
                        action: onDelete
                    )
                    .padding(.leading, SalusSpacing.sm)
                }

                chips
            }
        }
        .padding(.horizontal, SalusSpacing.lg)
    }

    /// The date tile and the text column — everything a tap on the row opens
    /// (`AppointmentCard.kt:73-101`).
    private var details: some View {
        HStack(alignment: .top, spacing: 0) {
            SalusDateTile(
                dayOfMonth: item.startsAt.date.day,
                monthShort: item.startsAt.formatted(pattern: monthPattern, locale: locale),
                accent: theme.extendedColors.appointments
            )

            // `Spacer(width = md)` between the tile and the content column
            // (`AppointmentCard.kt:79`).
            Spacer().frame(width: SalusSpacing.md)

            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: item.title)
                    .font(SalusTypography.titleMedium.font)
                    .foregroundStyle(theme.colorScheme.onSurface)
                    .lineLimit(2)
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

    /// `FlowRow(spacedBy = sm)` of the time chip and one neutral chip per reminder offset
    /// (`AppointmentCard.kt:102-119`).
    private var chips: some View {
        ChipFlowLayout(spacing: SalusSpacing.sm) {
            SalusStatusChip(
                label: item.startsAt.formatted(pattern: timePattern, locale: locale),
                status: .accent,
                systemImage: "clock"
            )
            ForEach(item.reminderOffsetsMinutes.sorted(), id: \.self) { offsetMinutes in
                SalusStatusChip(
                    label: offsetLabel(offsetMinutes),
                    status: .neutral,
                    systemImage: "bell"
                )
            }
        }
        .padding(.top, SalusSpacing.md)
    }
}

/// `AppointmentCard.kt:124-143`.
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
                .font(SalusTypography.bodySmall.font)
                .lineLimit(1)
        }
        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
        .padding(.top, SalusSpacing.xs)
    }
}

/// `AppointmentCard.kt:62`.
private let timePattern = "HH:mm"
/// `AppointmentCard.kt:63`.
private let monthPattern = "MMM"
/// `AppointmentCard.kt:133`.
private let detailIconSize: CGFloat = 16
