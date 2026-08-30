// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusIconBadge.kt:31-60`, in its default size only.
//
// Kotlin's composable takes `size`/`iconSize` (defaulting to 40/22) and an optional `accent`
// (defaulting to the primary role). Neither knob had a caller when the component shipped with
// iOS-M5, so the port was the two arguments that were actually used, with the file promising the
// rest "if and when a caller needs them".
//
// iOS-M8 is that caller: `App/Lock/AppLockScreen.swift` draws the large 72/32 badge in the primary
// role (`AppLockScreen.kt:43-47` passes no accent), which is exactly the pair of knobs that were
// deferred. Both arrive here, with `SalusIconBadgeDefaults` carrying the four Kotlin dimensions —
// `SalusEmptyState`'s private copy of the large badge (`SalusEmptyState.swift`) is now redundant
// and is left for the milestone that touches that file, since substituting it is a change to a
// component this task does not otherwise own.

import SalusDesignSystem
import SwiftUI

/// Icon inside a tinted circle — the shared leading visual for list rows, cards and detail
/// headers. `accent.container` fills the circle and `accent.accent` draws the icon — both read at
/// `SalusIconBadge.kt:38-39` and applied at `:43` and `:49`; with no accent it is the primary role,
/// as Kotlin's `accent?.accent ?: colorScheme.primary` has it (`SalusIconBadge.kt:38-39`).
public struct SalusIconBadge: View {
    private let systemImage: String
    private let accent: FeatureAccent?
    private let size: CGFloat
    private let iconSize: CGFloat

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - systemImage: SF Symbol name — the iOS twin of Kotlin's `ImageVector`.
    ///   - accent: the feature's accent, or `nil` for the primary role (`SalusIconBadge.kt:34`).
    ///   - size: the circle's diameter (`SalusIconBadge.kt:35`).
    ///   - iconSize: the symbol's size inside it (`SalusIconBadge.kt:36`).
    public init(
        systemImage: String,
        accent: FeatureAccent? = nil,
        size: CGFloat = SalusIconBadgeDefaults.size,
        iconSize: CGFloat = SalusIconBadgeDefaults.iconSize
    ) {
        self.systemImage = systemImage
        self.accent = accent
        self.size = size
        self.iconSize = iconSize
    }

    public var body: some View {
        // A capsule over a square frame is a circle; `SalusShapes.pill` is the token spelling of
        // Compose's `CircleShape` (`SalusIconBadge.kt:47`).
        SalusShapes.pill
            .fill(accent?.container ?? theme.colorScheme.primaryContainer)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: iconSize))
                    .foregroundStyle(accent?.accent ?? theme.colorScheme.primary)
            }
            // `contentDescription = null` (`SalusIconBadge.kt:53`): the badge repeats what the
            // row beside it already says.
            .accessibilityHidden(true)
    }
}

/// `object SalusIconBadgeDefaults` (`SalusIconBadge.kt:55-60`). Component dimensions, not design
/// tokens — Android keeps them in `:core:ui` too, not in `:core:designsystem`.
public enum SalusIconBadgeDefaults {
    /// `SalusIconBadgeDefaults.Size` (`SalusIconBadge.kt:56`).
    public static let size: CGFloat = 40
    /// `SalusIconBadgeDefaults.IconSize` (`SalusIconBadge.kt:57`).
    public static let iconSize: CGFloat = 22
    /// `SalusIconBadgeDefaults.LargeSize` (`SalusIconBadge.kt:58`).
    public static let largeSize: CGFloat = 72
    /// `SalusIconBadgeDefaults.LargeIconSize` (`SalusIconBadge.kt:59`).
    public static let largeIconSize: CGFloat = 32
}

#Preview("Icon badges") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack {
        theme.colorScheme.surfaceContainerLow
        HStack(spacing: SalusSpacing.sm) {
            SalusIconBadge(systemImage: "pills.fill", accent: theme.extendedColors.medications)
            SalusIconBadge(systemImage: "heart.fill", accent: theme.extendedColors.vitals)
            SalusIconBadge(systemImage: "calendar", accent: theme.extendedColors.appointments)
            // The two knobs iOS-M8 added: no accent (primary role) and the large size, which is
            // what `AppLockScreen` draws.
            SalusIconBadge(
                systemImage: "lock",
                size: SalusIconBadgeDefaults.largeSize,
                iconSize: SalusIconBadgeDefaults.largeIconSize
            )
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 120)
    .salusTheme(theme)
}
