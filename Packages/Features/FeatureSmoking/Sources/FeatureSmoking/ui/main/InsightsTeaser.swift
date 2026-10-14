// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// InsightsTeaser.kt`.
//
// The insights teaser under the goal card: one line that asks the question Trends answers. While
// locked a tap sells the feature, and the lock says so; unlocked it opens Trends. Both are the
// ViewModel's call, this only draws.

import SalusDesignSystem
import SalusUI
import SwiftUI

private enum TeaserSymbols {
    static let locked = "lock"
    static let insights = "chart.xyaxis.line"
    static let chevron = "chevron.right"
}

struct InsightsTeaser: View {
    let locked: Bool
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        let accent = theme.extendedColors.smoking
        SalusCard(onTap: onTap) {
            HStack(spacing: SalusSpacing.md) {
                SalusIconBadge(systemImage: locked ? TeaserSymbols.locked : TeaserSymbols.insights, accent: accent)
                VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                    Text(verbatim: SmokingStrings.insightsOverline)
                        .font(SalusTypography.labelSmall.font)
                        .tracking(SalusTypography.labelSmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    Text(verbatim: SmokingStrings.insightsTitle)
                        .font(SalusTypography.titleMedium.font)
                        .tracking(SalusTypography.titleMedium.tracking)
                        .foregroundStyle(theme.colorScheme.onSurface)
                    if locked {
                        Text(verbatim: SmokingStrings.premiumUnlock)
                            .font(SalusTypography.labelMedium.font)
                            .tracking(SalusTypography.labelMedium.tracking)
                            .foregroundStyle(accent.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !locked {
                    Image(systemName: TeaserSymbols.chevron)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}
