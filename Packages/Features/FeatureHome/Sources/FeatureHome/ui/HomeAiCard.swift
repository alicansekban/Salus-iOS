// Ported from `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/ui/HomeCards.kt` —
// `AiSummaryCard` (`:46-106`): the entry point to the AI health summary.
//
// Shown to everyone: the gate is in the repository, so a tap always opens the screen and the screen
// says whether a summary can be produced (`HomeCards.kt:47-53`).
//
// THE CARD'S EDGE IS THE POINT. `SalusCard(tone: .accentOutlined)` (`HomeCards.kt:64`) draws the
// standard ground inside a 1.5 pt frame of the `aiGradient` — `accentGlow` at the top falling to
// `aiGradient.bottom` (`SalusCard.swift:100-113`) — which is the one place in the app that edge is
// used, so the AI card is recognisable before a word of it is read.
//
// DIVERGENCE (d), A BUTTON WHERE KOTLIN HAS A CLICKABLE CARD. Compose carries the tap on the whole
// card and ends it with a "Detaylı İncele" label and a chevron as an affordance
// (`HomeCards.kt:61-65`, `:93-104`). Spec §4.1 gives iOS an explicit `SalusButton` instead, and a
// `Button` inside another `Button`'s label is swallowed by the outer one (``HomeDashboardCard``'s
// note) — so the card is non-interactive here and the button is what opens the summary. Two keys
// go unread as a result, `home_view_details` and the chip Kotlin gates on
// `HomeUiState.freeAiSummaryAvailable`; both are recorded in `HomeStrings.swift`'s header.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The AI health summary card (`AiSummaryCard`, `HomeCards.kt:55-106`).
struct HomeAiCard: View {
    let onOpenAiSummary: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard(tone: .accentOutlined) {
            // `Row(verticalAlignment = CenterVertically, spacedBy(md))` (`HomeCards.kt:66-85`).
            // `AutoAwesome` → `sparkles` (SF Symbol twin).
            HStack(spacing: SalusSpacing.md) {
                SalusIconBadge(systemImage: "sparkles", accent: theme.extendedColors.trends)
                // `verbatim:` because the string is already resolved; the plain initializer would
                // treat it as a `LocalizedStringKey` and look it up in the *main* bundle.
                Text(verbatim: HomeStrings.aiSummaryTitle)
                    .font(SalusTypography.titleLarge.font)
                    .tracking(SalusTypography.titleLarge.tracking)
                    // `Modifier.weight(1f)` (`HomeCards.kt:77`).
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // `Spacer(Modifier.height(SalusSpacing.md))` (`HomeCards.kt:86`).
            Spacer().frame(height: SalusSpacing.md)
            Text(verbatim: HomeStrings.aiSummaryDescription)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
            // `Spacer(Modifier.height(SalusSpacing.md))` then the trailing action
            // (`HomeCards.kt:92-104`) — divergence (d).
            Spacer().frame(height: SalusSpacing.md)
            SalusButton(HomeStrings.aiNewSummary, size: .medium, action: onOpenAiSummary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SalusSpacing.lg)
    }
}
