// The private row-building helpers `MoreScreen` composes — extracted from `MoreScreen.swift` to
// keep that file under the 500-line `file_length` gate. The four are the twin of the four
// `@Composable` helpers `MoreScreen.kt:360-449` and `EffectiveTheme.kt:13` carry inline in the
// Kotlin file: a section label, a tappable card, a toggle card, and the two-state
// `effectivePremiumTheme` collapse.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Section label above a group of cards (`MoreScreen.kt:360-368`). The scroll column already
/// applies the screen's horizontal inset, so the header drops its own — `topOnly` is the twin of
/// Kotlin's `contentPadding = PaddingValues(top = SalusSpacing.sm)` (`MoreScreen.kt:363-366`),
/// and without it every label would start a second `SalusSpacing.lg` in, out of line with the
/// card edges below it.
struct SectionLabel: View {
    let title: String

    var body: some View {
        SalusSectionHeader(title: title, contentPadding: SalusSectionHeaderDefaults.topOnly)
    }
}

/// One card: icon in a tinted circle, title + current value, chevron (`MoreScreen.kt:370-407`).
struct MoreCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let onClick: () -> Void
    var accent: FeatureAccent?

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard(onTap: onClick, contentPadding: SalusSpacing.lg) {
            HStack(spacing: SalusSpacing.md) {
                SalusIconBadge(systemImage: icon, accent: accent)
                VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                    Text(verbatim: title)
                        .font(SalusTypography.titleMedium.font)
                        .tracking(SalusTypography.titleMedium.tracking)
                    Text(verbatim: subtitle)
                        .font(SalusTypography.bodySmall.font)
                        .tracking(SalusTypography.bodySmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SalusListItemChevron()
            }
        }
    }
}

/// Card with a trailing switch; the whole card toggles when enabled (`MoreScreen.kt:409-449`).
struct MoreToggleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let checked: Bool
    let onCheckedChange: (Bool) -> Void
    var enabled = true

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard(
            onTap: enabled ? { onCheckedChange(!checked) } : nil,
            contentPadding: SalusSpacing.lg
        ) {
            HStack(spacing: SalusSpacing.md) {
                SalusIconBadge(systemImage: icon)
                VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                    Text(verbatim: title)
                        .font(SalusTypography.titleMedium.font)
                        .tracking(SalusTypography.titleMedium.tracking)
                    Text(verbatim: subtitle)
                        .font(SalusTypography.bodySmall.font)
                        .tracking(SalusTypography.bodySmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: SalusSpacing.sm)
                Toggle("", isOn: Binding(
                    get: { checked },
                    set: { onCheckedChange($0) }
                ))
                .labelsHidden()
                .disabled(!enabled)
                // The whole card is the tappable affordance, so VoiceOver reads the card once —
                // but the toggle itself is still a focusable control and must not be announced as
                // an unnamed "switch". The title is what the switch toggles, exactly as the row's
                // text names it; `Switch` on Android reads the enclosing label the same way
                // (`MoreScreen.kt:409-449`, `Modifier.semantics { }` on the card).
                .accessibilityLabel(title)
            }
        }
    }
}

/// `effectivePremiumTheme(status, selected)` (divergence 6). The Kotlin
/// `core/premium/.../EffectiveTheme.kt:13` reads `PremiumStatus.isEntitled`; the iOS collapse is
/// two-state (`MorePremiumStatusValue`), so the gate reads `== .entitled` — the shape
/// `MoreViewModel`'s gates use.
func effectivePremiumTheme(
    _ status: MorePremiumStatusValue,
    _ selected: PremiumTheme
) -> PremiumTheme {
    status == .entitled ? selected : .classic
}
