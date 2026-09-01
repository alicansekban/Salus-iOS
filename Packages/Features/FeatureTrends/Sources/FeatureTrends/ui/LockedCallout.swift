// Ported from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/TrendsScreen.kt:842-871`.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The card the scrim exists to make room for: what the wall is, and the one way through it
/// (`TrendsScreen.kt:842-871`).
///
/// Drawn in its own layer above the sample stack and the scrim, and the only thing on the locked
/// body that stays reachable: the sample stack behind it is `.allowsHitTesting(false)`, so this
/// card's button is the one touch target a free user has (`D-M11-a`).
struct LockedCallout: View {
    let onUpgrade: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack {
            Spacer()
            SalusCard(contentPadding: SalusSpacing.lg) {
                SalusIconBadge(systemImage: "lock", accent: theme.extendedColors.trends)
                Spacer().frame(height: SalusSpacing.md)
                Text(verbatim: TrendsStrings.lockedTitle)
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                Spacer().frame(height: SalusSpacing.xs)
                Text(verbatim: TrendsStrings.lockedMessage)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                Spacer().frame(height: SalusSpacing.lg)
                SalusPillButton(
                    text: TrendsStrings.lockedAction,
                    accent: theme.extendedColors.trends,
                    action: onUpgrade
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SalusSpacing.lg)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The button is the only thing on this body worth reaching, and it must stay reachable
        // while the sample stack behind it is not (`D-M11-a`).
        .allowsHitTesting(true)
    }
}
