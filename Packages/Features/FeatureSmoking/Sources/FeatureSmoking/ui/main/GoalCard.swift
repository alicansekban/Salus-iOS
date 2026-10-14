// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// GoalCard.kt`.
//
// The savings-goal card of the main screen, in QUIT and in REDUCE alike, and the two premium cards
// in screen order (``PremiumCards``). The whole card is one tap target: it opens the paywall while
// it is locked and the goal sheet otherwise (the ViewModel decides which). Amounts are drawn in
// whole currency units, like the other summaries.
//
// Compose → SwiftUI, beyond the shared mapping table:
//   `Icons.Outlined.*`            → SF Symbols, named in ``GoalSymbols``.
//   `SalusCard(onClick)`          → `SalusCard(onTap:)`, a `Button`, so VoiceOver already reads the
//                                   whole card as one element with the button trait.
//   `pluralStringResource(…)`     → `SmokingStrings.goalEta`, two keys picked by count.
//   `accent.accent` text colour   → `theme.extendedColors.smoking.accent`; no red, no pink.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The SF Symbols the premium cards use, named once.
private enum GoalSymbols {
    static let locked = "lock"
    static let none = "flag"
    static let reached = "trophy"
    static let chevron = "chevron.right"
}

private enum GoalDefaults {
    static let permille = 1000.0
}

/// The two premium cards, in screen order, shared by the QUIT and the REDUCE body. Both route their
/// tap through ``SmokingMainEvent``: what it does for a free account is the ViewModel's decision.
struct PremiumCards: View {
    let state: SmokingMainUiState
    let currencyCode: String
    let onEvent: (SmokingMainEvent) -> Void

    var body: some View {
        if let card = state.goalCard() {
            GoalCard(card: card, currencyCode: currencyCode, onTap: { onEvent(.goalTapped) })
        }
        InsightsTeaser(locked: !state.isPremium, onTap: { onEvent(.insightsTapped) })
    }
}

struct GoalCard: View {
    let card: GoalCardState
    let currencyCode: String
    let onTap: () -> Void

    var body: some View {
        SalusCard(onTap: onTap) {
            switch card {
            case .locked:
                LockedBody()

            case .none:
                NoneBody()

            case let .inProgress(goal):
                InProgressBody(goal: goal, currencyCode: currencyCode)

            case let .reached(title, target):
                ReachedBody(title: title, targetMinor: target, currencyCode: currencyCode)
            }
        }
    }
}

private struct GoalOverline: View {
    @Environment(\.salusTheme) private var theme

    var body: some View {
        Text(verbatim: SmokingStrings.goalOverline)
            .font(SalusTypography.labelSmall.font)
            .tracking(SalusTypography.labelSmall.tracking)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
    }
}

private struct LockedBody: View {
    @Environment(\.salusTheme) private var theme

    var body: some View {
        let accent = theme.extendedColors.smoking
        HStack(spacing: SalusSpacing.md) {
            SalusIconBadge(systemImage: GoalSymbols.locked, accent: accent)
            VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                GoalOverline()
                Text(verbatim: SmokingStrings.goalLockedBody)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                Text(verbatim: SmokingStrings.premiumUnlock)
                    .font(SalusTypography.labelMedium.font)
                    .tracking(SalusTypography.labelMedium.tracking)
                    .foregroundStyle(accent.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct NoneBody: View {
    @Environment(\.salusTheme) private var theme

    var body: some View {
        HStack(spacing: SalusSpacing.md) {
            SalusIconBadge(systemImage: GoalSymbols.none, accent: theme.extendedColors.smoking)
            VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                GoalOverline()
                Text(verbatim: SmokingStrings.goalNoneTitle)
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Chevron()
        }
    }
}

private struct InProgressBody: View {
    let goal: GoalInProgress
    let currencyCode: String

    @Environment(\.locale) private var locale
    @Environment(\.salusTheme) private var theme

    var body: some View {
        let accent = theme.extendedColors.smoking
        VStack(alignment: .leading, spacing: SalusSpacing.sm) {
            HStack(spacing: SalusSpacing.sm) {
                VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                    GoalOverline()
                    Text(verbatim: goal.title)
                        .font(SalusTypography.titleMedium.font)
                        .tracking(SalusTypography.titleMedium.tracking)
                        .foregroundStyle(theme.colorScheme.onSurface)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Chevron()
            }
            Text(verbatim: SmokingStrings.goalAmounts(money(goal.savedMinor), money(goal.targetMinor)))
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
            SalusProgressBar(progress: Double(goal.permille) / GoalDefaults.permille, accent: accent.accent)
            if let etaDays = goal.etaDays {
                Text(verbatim: SmokingStrings.goalEta(etaDays))
                    .font(SalusTypography.labelMedium.font)
                    .tracking(SalusTypography.labelMedium.tracking)
                    .foregroundStyle(accent.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func money(_ minor: Int64) -> String {
        formatMoney(minor: minor, currencyCode: currencyCode, locale: locale, showFraction: false)
    }
}

private struct ReachedBody: View {
    let title: String
    let targetMinor: Int64
    let currencyCode: String

    @Environment(\.locale) private var locale
    @Environment(\.salusTheme) private var theme

    var body: some View {
        let accent = theme.extendedColors.smoking
        HStack(spacing: SalusSpacing.md) {
            SalusIconBadge(systemImage: GoalSymbols.reached, accent: accent)
            VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                GoalOverline()
                Text(verbatim: SmokingStrings.goalReachedTitle)
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                Text(verbatim: SmokingStrings.goalReachedBody(title, money))
                    .font(SalusTypography.bodySmall.font)
                    .tracking(SalusTypography.bodySmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                Text(verbatim: SmokingStrings.goalReachedAction)
                    .font(SalusTypography.labelMedium.font)
                    .tracking(SalusTypography.labelMedium.tracking)
                    .foregroundStyle(accent.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var money: String {
        formatMoney(minor: targetMinor, currencyCode: currencyCode, locale: locale, showFraction: false)
    }
}

private struct Chevron: View {
    @Environment(\.salusTheme) private var theme

    var body: some View {
        Image(systemName: GoalSymbols.chevron)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            .accessibilityHidden(true)
    }
}
