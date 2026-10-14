// The twin of the goal and teaser `@Preview`s at the foot of `SmokingMainScreen.kt:338-380` and
// `GoalSheet.kt`: every state of the savings-goal card (locked, first goal, in progress, reached,
// and the long name that has to truncate), the insights teaser locked and unlocked, and the goal
// sheet empty, editing and with an unreadable amount, each in light and dark across the palettes
// (`SalusPreviewPalettes`), plus one Dynamic Type `.accessibility3` render per card group and for
// the sheet. A premium QUIT screen shows the cards in place.

import SalusDesignSystem
import SalusSmoking
import SalusUI
import SwiftUI

private enum GoalPreviewDefaults {
    /// 2026-03-10T12:00 Europe/Istanbul.
    static let nowMs: Int64 = 1_773_133_200_000
    static let dayMs: Int64 = 24 * 60 * 60 * 1000
    static let panelHeight: CGFloat = 820
    static let longTitle = "Kızımla birlikte çıkacağımız uzun bir Kapadokya tatili için biriktirdiğim para"
}

private let inProgress = GoalCardState.inProgress(
    GoalInProgress(title: "Yeni bisiklet", savedMinor: 315_000, targetMinor: 800_000, permille: 393, etaDays: 49)
)

private struct GoalCardsPreview: View {
    var body: some View {
        VStack(spacing: SalusSpacing.md) {
            GoalCard(card: .locked, currencyCode: "TRY", onTap: {})
            GoalCard(card: .none, currencyCode: "TRY", onTap: {})
            GoalCard(card: inProgress, currencyCode: "TRY", onTap: {})
            GoalCard(card: .reached(title: "Yeni bisiklet", targetMinor: 800_000), currencyCode: "TRY", onTap: {})
            InsightsTeaser(locked: true, onTap: {})
            InsightsTeaser(locked: false, onTap: {})
        }
        .padding(SalusSpacing.lg)
    }
}

#Preview("Goal cards — every state") {
    SalusPreviewPalettes { GoalCardsPreview() }
}

// The busiest cards under the largest text size a person can pick: a name longer than the card and
// an estimate under the figures.
#Preview("Goal cards — accessibility3") {
    VStack(spacing: SalusSpacing.md) {
        GoalCard(
            card: .inProgress(
                GoalInProgress(
                    title: GoalPreviewDefaults.longTitle,
                    savedMinor: 315_000,
                    targetMinor: 800_000,
                    permille: 393,
                    etaDays: 49
                )
            ),
            currencyCode: "TRY",
            onTap: {}
        )
        GoalCard(
            card: .reached(title: GoalPreviewDefaults.longTitle, targetMinor: 800_000),
            currencyCode: "TRY",
            onTap: {}
        )
        GoalCard(card: .locked, currencyCode: "TRY", onTap: {})
        InsightsTeaser(locked: true, onTap: {})
    }
    .padding(SalusSpacing.lg)
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
    .dynamicTypeSize(.accessibility3)
}

// MARK: - Screen

private func premiumQuit(goal: GoalProgress?) -> SmokingSnapshot {
    .quit(
        QuitSnapshot(
            plan: SmokingPlan(
                id: "plan",
                mode: .quit,
                productType: .cigarette,
                baselineUnitsPerDay: 20,
                dailyLimit: nil,
                currencyCode: "TRY",
                reason: nil,
                notificationsEnabled: true,
                eveningReminderEnabled: false,
                createdAtMs: GoalPreviewDefaults.nowMs - 50 * GoalPreviewDefaults.dayMs,
                tzId: "Europe/Istanbul"
            ),
            attemptId: "attempt",
            attemptStartedAtMs: GoalPreviewDefaults.nowMs - 42 * GoalPreviewDefaults.dayMs,
            attemptElapsedMs: 42 * GoalPreviewDefaults.dayMs,
            sinceLastSmokeMs: 42 * GoalPreviewDefaults.dayMs,
            slipCount: 0,
            unitsNotSmoked: 840,
            unitsNotSmokedToday: 0,
            savedMinor: 315_000,
            timeRegainedMinutes: 9240,
            cravingsBeaten: 17,
            cravingsBeatenAllTime: 17,
            stages: [],
            nextStage: nil,
            attempts: [],
            goal: goal
        )
    )
}

private func previewGoal(savedMinor: Int64, achievedAtMs: Int64? = nil) -> GoalProgress {
    let target: Int64 = 800_000
    return GoalProgress(
        goal: SavingsGoal(
            id: "goal",
            title: "Yeni bisiklet",
            targetMinor: target,
            createdAtMs: GoalPreviewDefaults.nowMs - 10 * GoalPreviewDefaults.dayMs,
            achievedAtMs: achievedAtMs
        ),
        savedTowardMinor: savedMinor,
        permille: Int(min(1000, savedMinor * 1000 / target)),
        reached: savedMinor >= target || achievedAtMs != nil
    )
}

private struct PremiumMainPreview: View {
    let goal: GoalProgress?

    var body: some View {
        NavigationStack {
            SmokingMainScreen(
                state: SmokingMainUiState(snapshot: premiumQuit(goal: goal), isPremium: true),
                onEvent: { _ in },
                counterClock: .frozen(atMs: GoalPreviewDefaults.nowMs)
            )
        }
        .frame(height: GoalPreviewDefaults.panelHeight)
    }
}

#Preview("Main — premium, first goal") {
    SalusPreviewPalettes { PremiumMainPreview(goal: nil) }
}

#Preview("Main — premium, goal in progress") {
    SalusPreviewPalettes { PremiumMainPreview(goal: previewGoal(savedMinor: 315_000)) }
}

#Preview("Main — premium, goal reached") {
    SalusPreviewPalettes { PremiumMainPreview(goal: previewGoal(savedMinor: 812_500)) }
}

// MARK: - Goal sheet

#Preview("Goal sheet — new, editing and unreadable") {
    SalusPreviewPalettes {
        GoalSheetContent(
            title: .constant(""),
            amountText: .constant(""),
            currencyCode: "TRY",
            editing: false,
            writing: false,
            onSave: {}
        )
        // A goal in progress: both fields filled, and the note that its savings are kept.
        GoalSheetContent(
            title: .constant("Yeni bisiklet"),
            amountText: .constant("8000"),
            currencyCode: "TRY",
            editing: true,
            writing: false,
            onSave: {}
        )
        // An amount that cannot be a target: the field says so and "Kaydet" stays off.
        GoalSheetContent(
            title: .constant("Yeni bisiklet"),
            amountText: .constant("0"),
            currencyCode: "TRY",
            editing: false,
            writing: false,
            onSave: {}
        )
    }
}

#Preview("Goal sheet — accessibility3") {
    GoalSheetContent(
        title: .constant("Yeni bisiklet"),
        amountText: .constant("8000"),
        currencyCode: "TRY",
        editing: true,
        writing: false,
        onSave: {}
    )
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
    .dynamicTypeSize(.accessibility3)
}
