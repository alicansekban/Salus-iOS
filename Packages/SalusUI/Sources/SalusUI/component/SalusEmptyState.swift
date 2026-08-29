// Ported from `core/ui/.../component/SalusEmptyState.kt:29-72`.
//
// Kotlin composes two other `:core:ui` components here — `SalusIconBadge` (`SalusEmptyState.kt:45`)
// and `SalusPillButton` (`:69`). Neither was part of the iOS-M2 component set (they arrive with the
// feature that first needs them on their own), so both were hand-drawn here as private views
// rather than as public API that milestone did not owe.
//
// One of the two copies is now gone: `SalusPillButton` shipped with iOS-M6 and this file calls it
// (iOS-M7 — the last of the three inline pills the M6 plan deferred). `SalusIconBadge` shipped
// with iOS-M5 too, but in its *default* 40/22 size, which is not the 72/32 one this file draws, so
// the private badge below stays until a caller needs the large one as public API too. Its
// dimensions are cited to the Kotlin they copy.

import SalusDesignSystem
import SwiftUI

/// Empty-state block: large icon in a tinted circle, a title, an optional supporting message
/// and an optional call-to-action pill button. Pass the feature's `FeatureAccent` to tint the
/// icon circle; it defaults to the primary role (`SalusEmptyState.kt:24-28`).
public struct SalusEmptyState: View {
    private let systemImage: String
    private let title: String
    private let message: String?
    private let accent: FeatureAccent?
    private let actionLabel: String?
    private let onAction: (() -> Void)?

    @Environment(\.salusTheme) private var theme

    /// - Parameter systemImage: SF Symbol name — the iOS twin of Kotlin's `ImageVector`.
    public init(
        systemImage: String,
        title: String,
        message: String? = nil,
        accent: FeatureAccent? = nil,
        actionLabel: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.accent = accent
        self.actionLabel = actionLabel
        self.onAction = onAction
    }

    public var body: some View {
        // Spacing is per-gap in Kotlin (`Spacer(height = …)` between children), not one uniform
        // step, so the stack carries none and each gap is spelled out as it is there.
        VStack(spacing: 0) {
            iconBadge
            Spacer().frame(height: SalusSpacing.lg)
            Text(title)
                .font(SalusTypography.titleLarge.font)
                .tracking(SalusTypography.titleLarge.tracking)
                .foregroundStyle(colors.onSurface)
                .multilineTextAlignment(.center)
            if let message {
                Spacer().frame(height: SalusSpacing.sm)
                Text(message)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
            if let actionLabel, let onAction {
                Spacer().frame(height: SalusSpacing.xl)
                // `SalusPillButton(text = actionLabel, onClick = onAction)`
                // (`SalusEmptyState.kt:69`) — the default filled, content-width pill. This was
                // hand-drawn here until `SalusPillButton` shipped with iOS-M6; the component draws
                // the identical capsule, so the copy is gone.
                SalusPillButton(text: actionLabel, action: onAction)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(SalusSpacing.xl)
    }

    private var colors: SalusColorScheme { theme.colorScheme }

    /// `SalusIconBadge(size = LargeSize, iconSize = LargeIconSize)`
    /// (`SalusEmptyState.kt:45-50`, `SalusIconBadge.kt:31-60`).
    private var iconBadge: some View {
        Circle()
            .fill(accent?.container ?? colors.primaryContainer)
            .frame(width: Self.badgeSize, height: Self.badgeSize)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: Self.badgeIconSize))
                    .foregroundStyle(accent?.accent ?? colors.primary)
                    // Decoration, not content: `SalusIconBadge.kt:48` passes
                    // `contentDescription = null`, and the title below already says what the
                    // empty state is about. Without this the symbol's own name is announced.
                    .accessibilityHidden(true)
            }
    }

    /// `SalusIconBadgeDefaults.LargeSize` / `.LargeIconSize` (`SalusIconBadge.kt:58-59`). Component
    /// dimensions, not design tokens — Android keeps them in `:core:ui` too, not in
    /// `:core:designsystem`.
    private static let badgeSize: CGFloat = 72
    private static let badgeIconSize: CGFloat = 32
}

#Preview("Empty state") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack {
        theme.colorScheme.background
        SalusEmptyState(
            systemImage: "heart.fill",
            title: "No measurements yet",
            message: "Add your first measurement to start tracking trends.",
            accent: theme.extendedColors.vitals,
            actionLabel: "Add measurement",
            onAction: {}
        )
    }
    .salusTheme(theme)
}
