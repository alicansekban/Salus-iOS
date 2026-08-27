// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusIconBadge.kt:31-60`, in its default size only.
//
// Kotlin's composable takes `size`/`iconSize` (defaulting to 40/22) and an optional `accent`
// (defaulting to the primary role). Neither knob has a caller on iOS: the one place that wants
// the large 72/32 badge is `SalusEmptyState`, which draws its own, and every list row and detail
// header names the feature accent it belongs to. So this port is the two arguments that are
// actually used; the parameters arrive if and when a caller needs them.

import SalusDesignSystem
import SwiftUI

/// Icon inside a tinted circle — the shared leading visual for list rows, cards and detail
/// headers. `accent.container` fills the circle, `accent.accent` draws the icon
/// (`SalusIconBadge.kt:44-45`).
public struct SalusIconBadge: View {
    private let systemImage: String
    private let accent: FeatureAccent

    /// - Parameter systemImage: SF Symbol name — the iOS twin of Kotlin's `ImageVector`.
    public init(systemImage: String, accent: FeatureAccent) {
        self.systemImage = systemImage
        self.accent = accent
    }

    public var body: some View {
        // A capsule over a square frame is a circle; `SalusShapes.pill` is the token spelling of
        // Compose's `CircleShape` (`SalusIconBadge.kt:47`).
        SalusShapes.pill
            .fill(accent.container)
            .frame(width: Self.size, height: Self.size)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: Self.iconSize))
                    .foregroundStyle(accent.accent)
            }
            // `contentDescription = null` (`SalusIconBadge.kt:53`): the badge repeats what the
            // row beside it already says.
            .accessibilityHidden(true)
    }

    /// `SalusIconBadgeDefaults.Size` / `.IconSize` (`SalusIconBadge.kt:56-57`). Component
    /// dimensions, not design tokens — Android keeps them in `:core:ui` too, not in
    /// `:core:designsystem`.
    private static let size: CGFloat = 40
    private static let iconSize: CGFloat = 22
}

#Preview("Icon badges") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack {
        theme.colorScheme.surfaceContainerLow
        HStack(spacing: SalusSpacing.sm) {
            SalusIconBadge(systemImage: "pills.fill", accent: theme.extendedColors.medications)
            SalusIconBadge(systemImage: "heart.fill", accent: theme.extendedColors.vitals)
            SalusIconBadge(systemImage: "calendar", accent: theme.extendedColors.appointments)
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 120)
    .salusTheme(theme)
}
