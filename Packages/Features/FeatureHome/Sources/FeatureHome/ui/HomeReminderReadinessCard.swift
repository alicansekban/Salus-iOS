// Ported 1:1 from `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/ui/
// HomeCards.kt:198-238` (`ReminderReadinessCard`), the steering card that tells the user their
// reminders are in trouble and takes them to Reminder health.
//
// A file of its own for the reason every other dashboard card has one: Kotlin can keep them
// `private` inside one file, Swift cannot, so each is an internal `View` this package alone can
// name (`HomeScreen.swift`'s header).
//
// Three things about it are load-bearing:
//
//   **It sits between the hero band and the snapshot pager** (`HomeScreen.kt:152-162`, after owner
//   QA): the card exists only when reminders are degraded or broken, so it belongs right above the
//   doses it is about — under the greeting, not above it. M15 moved it there from the top of the
//   screen, and `reminderReadiness` is nil while everything is healthy, so nothing shifts down in
//   the normal case.
//
//   **There is no dismiss.** The card leaves on its own the moment an arrival reads a healthy
//   device — `HomeViewModel.refreshReminderReadiness()` stores nil and the `if let` below stops
//   matching. A dismissable warning about a silent alarm is a warning the user turns off once and
//   never sees again.
//
//   **The whole card is the tap target**, so it goes through ``HomeDashboardCard``'s `onTap:`
//   branch — a real `Button` with the button semantics and VoiceOver that buys. It contains no
//   interactive child, so the nested-button problem the doses and appointments cards have does not
//   arise here (`HomeDashboardCard`'s doc comment).

import SalusDesignSystem
import SalusReminder
import SalusUI
import SwiftUI

/// "Alarms will not fire" / "Alarms may be late", one line on why, and a chevron to Reminder
/// health (`HomeCards.kt:202-238`).
struct HomeReminderReadinessCard: View {
    /// The report the ViewModel stored. Never ``ReminderReadiness/ok`` — that is stored as nil and
    /// this card is not built for it; ``HomeStrings/remindersTitle(_:)`` traps if it ever is.
    let report: ReminderReadinessReport
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        HomeDashboardCard(onTap: onTap) {
            // `Row(verticalAlignment = CenterVertically, spacedBy(md))` (`HomeCards.kt:209-231`).
            // The greedy frame on the title is Kotlin's `Modifier.weight(1f)` (`:228`) and what
            // keeps it flush left inside the `Button` the card is. `NotificationsOff` →
            // `bell.slash` (SF Symbol twin).
            HStack(spacing: SalusSpacing.md) {
                SalusIconBadge(systemImage: "bell.slash", accent: theme.extendedColors.medications)
                Text(verbatim: HomeStrings.remindersTitle(report.readiness))
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SalusListItemChevron()
            }
            // `Spacer(Modifier.height(SalusSpacing.md))` (`HomeCards.kt:232`).
            Spacer().frame(height: SalusSpacing.md)
            // M15 moved the reason out of a plain line and into a warning note
            // (`HomeCards.kt:233-236`). `problems.first()` (`:234`): the list is in worst-first
            // declaration order, so the first is the one worth a single line. A report with no
            // problems is `ok`, which is never drawn — hence the `?? ""` rather than a second
            // empty-state. Kotlin defaults the note's icon; SF Symbols has no one name that fits
            // all three tones, so `SalusInfoNote` takes it from the caller
            // (`SalusInfoNote.swift:4-6`) and the warning tone is given the warning triangle.
            SalusInfoNote(
                text: report.problems.first?.reason ?? "",
                systemImage: "exclamationmark.triangle",
                tone: .warning
            )
        }
    }
}

#Preview("Reminder readiness card") {
    VStack(spacing: SalusSpacing.sm) {
        HomeReminderReadinessCard(
            report: ReminderReadinessReport(problems: [.notificationsOff]),
            onTap: {}
        )
        HomeReminderReadinessCard(
            report: ReminderReadinessReport(problems: [.alarmKitDenied]),
            onTap: {}
        )
    }
    .padding(.vertical, SalusSpacing.sm)
}
