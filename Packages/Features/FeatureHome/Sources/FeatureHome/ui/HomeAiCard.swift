// Ported from `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/ui/HomeCards.kt` —
// `AiSummaryCard` (`:56-106`): the entry point to the AI health summary.
//
// Shown to everyone: the gate is in the repository, so a tap always opens the screen and the screen
// says whether a summary can be produced. **Only the chip is conditional** — it announces an unspent
// free summary, and promising one that is already gone would be worse than no chip
// (`HomeCards.kt:46-54`). The card itself carries the tap, so the trailing line is an affordance
// rather than a second control a screen reader has to step through.
//
// THE CARD'S EDGE IS THE POINT. `SalusCard(tone: .accentOutlined)` (`HomeCards.kt:64`) draws the
// standard ground inside a 1.5 pt frame of the `aiGradient` — `accentGlow` at the top falling to
// `aiGradient.bottom` (`SalusCard.swift:100-113`) — which is the one place in the app that edge is
// used, so the AI card is recognisable before a word of it is read.
//
// NO DIVERGENCE HERE, and the shape is load-bearing in two ways a rewrite keeps breaking:
//
//   **The whole card is the tap target** (`HomeCards.kt:61-65`), not a button inside it. It holds no
//   interactive child, so `SalusCard(onTap:)`'s `Button` branch is safe — free button semantics and
//   free VoiceOver, and the "Detayları gör" line stays one glance rather than a second stop for a
//   screen reader. A `SalusButton` in here would make the card non-interactive and add exactly the
//   control Kotlin's doc comment says not to add.
//
//   **The chip is gated on `freeAiSummaryAvailable`** (`HomeCards.kt:79-84`, passed at
//   `HomeScreen.kt:174-175`). Drawing it unconditionally tells a user with no credit left that a
//   free summary is waiting. `isPremium` is deliberately *not* read: Kotlin's card reads only this
//   one flag, and the entitlement decides what the summary screen can do, not what this card says.
//
// Material → SwiftUI:
//   `Row(verticalAlignment = CenterVertically, spacedBy(md))` → `HStack(spacing: SalusSpacing.md)`.
//   `Modifier.weight(1f)`                                     → a greedy leading-aligned frame.
//   `Modifier.align(Alignment.End)`                           → a trailing-aligned greedy frame.
//   `Icons.Outlined.AutoAwesome`                              → `sparkles` (SF Symbol twin).

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The AI health summary card (`AiSummaryCard`, `HomeCards.kt:56-106`).
struct HomeAiCard: View {
    /// `newSummaryAvailable` (`HomeCards.kt:57`) — `state.freeAiSummaryAvailable` at the call site
    /// (`HomeScreen.kt:175`). The card's one conditional.
    let newSummaryAvailable: Bool
    let onOpenAiSummary: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard(tone: .accentOutlined, onTap: onOpenAiSummary) {
            titleRow
            // `Spacer(Modifier.height(SalusSpacing.md))` (`HomeCards.kt:86`).
            Spacer().frame(height: SalusSpacing.md)
            // `verbatim:` because the string is already resolved; the plain initializer would treat
            // it as a `LocalizedStringKey` and look it up in the *main* bundle.
            Text(verbatim: HomeStrings.aiSummaryDescription)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                // The greedy frame keeps the paragraph flush left inside the `Button` the card is:
                // SwiftUI centers a `Button`'s label when it does not fill the width.
                .frame(maxWidth: .infinity, alignment: .leading)
            // `Spacer(Modifier.height(SalusSpacing.md))` (`HomeCards.kt:92`).
            Spacer().frame(height: SalusSpacing.md)
            detailsAffordance
        }
        .frame(maxWidth: .infinity)
        // `Modifier.padding(horizontal = SalusSpacing.lg)` at the call site (`HomeScreen.kt:179`).
        .padding(.horizontal, SalusSpacing.lg)
    }

    /// Badge, title and the gated chip (`HomeCards.kt:66-85`).
    private var titleRow: some View {
        HStack(spacing: SalusSpacing.md) {
            SalusIconBadge(systemImage: "sparkles", accent: theme.extendedColors.trends)
            Text(verbatim: HomeStrings.aiSummaryTitle)
                .font(SalusTypography.titleLarge.font)
                .tracking(SalusTypography.titleLarge.tracking)
                // `Modifier.weight(1f)` (`HomeCards.kt:77`).
                .frame(maxWidth: .infinity, alignment: .leading)
            // `if (newSummaryAvailable) { SalusStatusChip(home_ai_new_summary, Accent) }`
            // (`HomeCards.kt:79-84`).
            if newSummaryAvailable {
                SalusStatusChip(label: HomeStrings.aiNewSummary, status: .accent)
            }
        }
    }

    /// The trailing "Detayları gör" line and its chevron (`HomeCards.kt:93-104`).
    ///
    /// Text, not a control: the card is the button, and this says where a tap goes. It is inside the
    /// card's own accessibility element for the same reason Kotlin leaves it a plain `Row`.
    private var detailsAffordance: some View {
        HStack(spacing: SalusSpacing.xs) {
            Text(verbatim: HomeStrings.viewDetails)
                .font(SalusTypography.labelLarge.font)
                .tracking(SalusTypography.labelLarge.tracking)
                .foregroundStyle(theme.colorScheme.primary)
            SalusListItemChevron()
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
