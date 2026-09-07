// Ported 1:1 from `HomeScreen.kt:564-604` (`ReminderReadinessCard`), the steering card that tells
// the user their reminders are in trouble and takes them to Reminder health.
//
// A file of its own for the reason every other dashboard card has one: Kotlin can keep them
// `private` inside `HomeScreen.kt`, Swift cannot, so each is an internal `View` this package alone
// can name (`HomeScreen.swift`'s header).
//
// Three things about it are load-bearing:
//
//   **It is drawn first**, above the doses section header (`HomeScreen.kt:173-176`, whose comment
//   says a dose list is worthless when the alarm behind it cannot fire). That is the one exception
//   to "doses are the first thing the user sees", and it is Android's.
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
/// health (`HomeScreen.kt:568-604`).
struct HomeReminderReadinessCard: View {
    /// The report the ViewModel stored. Never ``ReminderReadiness/ok`` — that is stored as nil and
    /// this card is not built for it; ``HomeStrings/remindersTitle(_:)`` traps if it ever is.
    let report: ReminderReadinessReport
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        HomeDashboardCard(onTap: onTap) {
            // `Row(verticalAlignment = CenterVertically)` (`HomeScreen.kt:574`). The greedy frame
            // on the text column is Kotlin's `Modifier.weight(1f)` (`:580`) and, as in the AI card,
            // what keeps the text flush left inside the `Button` the card is.
            HStack(spacing: 0) {
                SalusIconBadge(systemImage: "bell.slash", accent: theme.extendedColors.medications)
                Spacer().frame(width: SalusSpacing.md)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: HomeStrings.remindersTitle(report.readiness))
                        .font(SalusTypography.titleMedium.font)
                        .tracking(SalusTypography.titleMedium.tracking)
                        .foregroundStyle(theme.colorScheme.onSurface)
                    // `problems.first()` (`HomeScreen.kt:595`): the list is in worst-first
                    // declaration order, so the first is the one worth a single line. A report
                    // with no problems is `ok`, which is never drawn — hence the `?? ""` rather
                    // than a second empty-state.
                    Text(verbatim: report.problems.first?.reason ?? "")
                        .font(SalusTypography.bodyMedium.font)
                        .tracking(SalusTypography.bodyMedium.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: SalusSpacing.sm)
                SalusListItemChevron()
            }
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
