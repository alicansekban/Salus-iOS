// Ported 1:1 from
// `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingHero.kt:31-61` (M15/M16).
//
// The decorative shield/bell cluster the eight-step flow opened on is gone with the flow: M15
// gives every page the same opening — one glyph in a tile over the page's title and its sentence
// of explanation — so the hero is now a shared header rather than two hand-drawn illustrations.
//
// Material → SwiftUI:
//   `SalusIconBadge(size = LargeSize,  → `SalusIconBadge(systemImage:size:iconSize:)`, the raw-size
//     iconSize = LargeIconSize,          initializer the component keeps for exactly this 72/32
//     shape = shapes.large)`             badge. The `shape` argument has no iOS twin: `SalusIconBadge`
//                                        is a circle on this side (`SalusIconBadge.swift:78-80`),
//                                        so the tile is round rather than a 24 pt rounded square.
//                                        A component-level difference, not a page-level one — it is
//                                        `SalusUI`'s to change, and no caller may redraw it locally.
//   `Column(horizontalAlignment =      → a `VStack` with `.multilineTextAlignment(.center)` on both
//     CenterHorizontally)`               labels and `.frame(maxWidth: .infinity)` on the column.
//   `headlineMedium` / `bodyMedium`    → the same two `SalusTypography` roles.
//
// The tile is decorative: `SalusIconBadge` carries no accessibility label on either platform, and
// the title underneath is what a screen reader announces (`OnboardingHero.kt:25-29`).

import SalusDesignSystem
import SalusUI
import SwiftUI

/// How every onboarding page opens (`OnboardingHero.kt:30-61`).
struct OnboardingHero: View {
    let systemImage: String
    let title: String
    /// Kotlin's `body`; named `message` here because `body` is `View`'s own requirement.
    let message: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // `Arrangement.spacedBy(SalusSpacing.md)` (`OnboardingHero.kt:40`).
        VStack(spacing: SalusSpacing.md) {
            SalusIconBadge(
                systemImage: systemImage,
                size: SalusIconBadgeDefaults.largeSize,
                iconSize: SalusIconBadgeDefaults.largeIconSize
            )
            // `Text(verbatim:)` on both: a resolved string handed to `Text(_:)` is re-read as a
            // `LocalizedStringKey` against the main bundle (the M7 `c726e22` finding).
            Text(verbatim: title)
                .font(SalusTypography.headlineMedium.font)
                .tracking(SalusTypography.headlineMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            Text(verbatim: message)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity)
    }
}

// `OnboardingHeroPreview` (`OnboardingHero.kt:63-76`).
#Preview("Onboarding hero") {
    SalusPreviewPalettes {
        OnboardingHero(
            systemImage: "shield",
            title: OnboardingStrings.onboardingWelcomeTitle,
            message: OnboardingStrings.onboardingWelcomeBody
        )
    }
}
