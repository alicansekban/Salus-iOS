// The private row-building helpers `MoreScreen` composes — extracted from `MoreScreen.swift` to
// keep that file under the 500-line `file_length` gate. The four are the twin of the four
// `@Composable` helpers `MoreScreen.kt:360-449` and `EffectiveTheme.kt:13` carry inline in the
// Kotlin file: a section label, a tappable card, a toggle card, and the two-state
// `effectivePremiumTheme` collapse.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Section label above a group of cards (`MoreScreen.kt:360-368`). `SalusSectionHeader(title:)`
/// with no horizontal padding of its own — the scroll column carries none and each card carries the
/// screen inset instead (see `MoreScreen.swift`'s header). The Kotlin's `top = sm` is the header's
/// own `SalusSpacing.sm` vertical padding.
struct SectionLabel: View {
    let title: String

    var body: some View {
        SalusSectionHeader(title: title)
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
