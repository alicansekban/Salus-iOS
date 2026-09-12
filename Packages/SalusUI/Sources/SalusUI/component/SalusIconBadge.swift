// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusIconBadge.kt:31-60` in its M15 shape.
//
// Kotlin's composable takes `size`/`iconSize` (defaulting to 40/22) and an optional `accent`
// (defaulting to the primary role). The M15 badge adds the three named sizes below — 24 inline,
// 40 the list-row tile, 48 header/sheet scale (`SalusIconBadge.kt:63-79`) — while the large
// 72/32 badge that `AppLockScreen` and onboarding draw stays behind `SalusIconBadgeDefaults`.
//
// `accent.container` fills the circle and `accent.accent` draws the icon — both read at
// `SalusIconBadge.kt:46-47` and applied at `:51-60`; with no accent it is the primary role, as
// Kotlin's `accent?.accent ?: colorScheme.primary` has it.

import SalusDesignSystem
import SwiftUI

/// Icon inside a tinted circle — the shared leading visual for list rows, cards and detail
/// headers. Pass the feature's `FeatureAccent`; defaults to the primary role.
public struct SalusIconBadge: View {
    /// The three named sizes (`SalusIconBadge.kt:63-79`).
    public enum Size {
        /// 24 pt — inline with text, a status glyph beside a label.
        case small
        /// 40 pt — the list-row tile. The default.
        case medium
        /// 48 pt — header and sheet scale, and the size a tappable badge has to reach.
        case large
    }

    private let systemImage: String
    private let accent: FeatureAccent?
    private let size: CGFloat
    private let iconSize: CGFloat

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - systemImage: SF Symbol name — the iOS twin of Kotlin's `ImageVector`.
    ///   - accent: the feature's accent, or `nil` for the primary role (`SalusIconBadge.kt:41`).
    ///   - size: the circle's diameter (`SalusIconBadge.kt:42`).
    ///   - iconSize: the symbol's size inside it (`SalusIconBadge.kt:43`).
    public init(
        systemImage: String,
        accent: FeatureAccent? = nil,
        size: SalusIconBadge.Size = .medium
    ) {
        self.systemImage = systemImage
        self.accent = accent
        switch size {
        case .small:
            self.size = SalusIconBadgeDefaults.small
            iconSize = SalusIconBadgeDefaults.smallIconSize

        case .medium:
            self.size = SalusIconBadgeDefaults.size
            iconSize = SalusIconBadgeDefaults.iconSize

        case .large:
            self.size = SalusIconBadgeDefaults.mediumSize
            iconSize = SalusIconBadgeDefaults.mediumIconSize
        }
    }

    /// The raw-size initializer for the 72/32 badge (`AppLockScreen`, onboarding): keeps the
    /// Kotlin `size`/`iconSize` signature for the one size that has no named case.
    public init(
        systemImage: String,
        accent: FeatureAccent? = nil,
        size: CGFloat,
        iconSize: CGFloat
    ) {
        self.systemImage = systemImage
        self.accent = accent
        self.size = size
        self.iconSize = iconSize
    }

    public var body: some View {
        // A capsule over a square frame is a circle; `SalusShapes.pill` is the token spelling of
        // Compose's `CircleShape` (`SalusIconBadge.kt:51-54`).
        SalusShapes.pill
            .fill(accent?.container ?? theme.colorScheme.primaryContainer)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: iconSize))
                    .foregroundStyle(accent?.accent ?? theme.colorScheme.primary)
            }
            // `contentDescription = null` (`SalusIconBadge.kt:56-59`): the badge repeats what the
            // row beside it already says.
            .accessibilityHidden(true)
    }
}

/// `object SalusIconBadgeDefaults` (`SalusIconBadge.kt:63-79`). Component dimensions, not design
/// tokens — Android keeps them in `:core:ui` too, not in `:core:designsystem`.
public enum SalusIconBadgeDefaults {
    /// `SalusIconBadgeDefaults.Small` / `.SmallIconSize` (`SalusIconBadge.kt:65-66`).
    public static let small: CGFloat = 24
    public static let smallIconSize: CGFloat = 14
    /// `SalusIconBadgeDefaults.Size` / `.IconSize` (`SalusIconBadge.kt:69-70`) — the default,
    /// a list-row tile.
    public static let size: CGFloat = 40
    public static let iconSize: CGFloat = 22
    /// `SalusIconBadgeDefaults.Medium` / `.MediumIconSize` (`SalusIconBadge.kt:73-74`).
    public static let mediumSize: CGFloat = 48
    public static let mediumIconSize: CGFloat = 24
    /// `SalusIconBadgeDefaults.LargeSize` / `.LargeIconSize` (`SalusIconBadge.kt:77-78`) — the
    /// empty state's illustration, still drawn by `SalusEmptyState`'s private copy.
    public static let largeSize: CGFloat = 72
    public static let largeIconSize: CGFloat = 32
}

#Preview("Icon badges") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    ZStack {
        theme.colorScheme.surfaceContainerLow
        HStack(spacing: SalusSpacing.sm) {
            SalusIconBadge(systemImage: "pills.fill", size: .small)
            SalusIconBadge(systemImage: "heart.fill", accent: theme.extendedColors.vitals)
            SalusIconBadge(
                systemImage: "calendar",
                accent: theme.extendedColors.appointments,
                size: .large
            )
            // The two knobs the raw-size initializer keeps: no accent (primary role) and the
            // large 72 badge, which is what `AppLockScreen` draws.
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

#Preview("Icon badges — dark") {
    let theme = SalusTheme.resolve(systemIsDark: true)
    ZStack {
        theme.colorScheme.surfaceContainerLow
        HStack(spacing: SalusSpacing.sm) {
            SalusIconBadge(systemImage: "pills.fill", size: .small)
            SalusIconBadge(systemImage: "heart.fill", accent: theme.extendedColors.vitals)
            SalusIconBadge(
                systemImage: "calendar",
                accent: theme.extendedColors.appointments,
                size: .large
            )
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 120)
    .salusTheme(theme)
}
