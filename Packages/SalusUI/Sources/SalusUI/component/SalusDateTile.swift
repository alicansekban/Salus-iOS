// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusDateTile.kt:27-60`.
//
// Kotlin's composable takes `dayOfMonth`, `monthShort`, and an optional `accent` (defaulting to the
// primary role: `accent?.container ?: colorScheme.primaryContainer` and
// `accent?.accent ?: colorScheme.primary`, `SalusDateTile.kt:34-35`). The tile is a 56×60 rounded
// rectangle with the `small` corner radius (`MaterialTheme.shapes.small`, `SalusDateTile.kt:40`),
// filled with the accent's container, and the day (`headlineMedium`) above the month
// (`labelMedium`), both in the accent's accent color (`SalusDateTile.kt:44-53`).

import SalusDesignSystem
import SwiftUI

/// Compact stacked date tile for a single appointment — the leading visual in the Appointments
/// list. Shows the day of month above a short month label on the feature's tinted container
/// (`SalusDateTile.kt:22-26`).
public struct SalusDateTile: View {
    private let dayOfMonth: Int
    private let monthShort: String
    private let accent: FeatureAccent?

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - dayOfMonth: the day number, drawn in `headlineMedium` (`SalusDateTile.kt:44-48`).
    ///   - monthShort: the short month label, drawn in `labelMedium` (`SalusDateTile.kt:49-53`).
    ///   - accent: the feature's accent; `nil` falls back to the primary role
    ///     (`SalusDateTile.kt:34-35`).
    public init(
        dayOfMonth: Int,
        monthShort: String,
        accent: FeatureAccent? = nil
    ) {
        self.dayOfMonth = dayOfMonth
        self.monthShort = monthShort
        self.accent = accent
    }

    public var body: some View {
        // `MaterialTheme.shapes.small` (`SalusDateTile.kt:40`) is the design system's `small`
        // corner radius token (`SalusShapes.small` = 12).
        SalusShapes.smallShape
            .fill(SalusDateTileStyle.container(accent: accent, theme: theme))
            .frame(width: SalusDateTileDefaults.width, height: SalusDateTileDefaults.height)
            .overlay {
                VStack(spacing: 0) {
                    Text(verbatim: String(dayOfMonth))
                        .font(SalusTypography.headlineMedium.font)
                        .tracking(SalusTypography.headlineMedium.tracking)
                        .foregroundStyle(SalusDateTileStyle.tint(accent: accent, theme: theme))
                    Text(verbatim: monthShort)
                        .font(SalusTypography.labelMedium.font)
                        .tracking(SalusTypography.labelMedium.tracking)
                        .foregroundStyle(SalusDateTileStyle.tint(accent: accent, theme: theme))
                }
            }
    }
}

/// The two accent resolutions of `SalusDateTile.kt:34-35`, hoisted out of the view so the fallback
/// is testable without rendering it — the shape `SalusOptionRowStyle` sets.
enum SalusDateTileStyle {
    /// `accent?.container ?: colorScheme.primaryContainer` (`SalusDateTile.kt:34`).
    static func container(accent: FeatureAccent?, theme: SalusResolvedTheme) -> Color {
        accent?.container ?? theme.colorScheme.primaryContainer
    }

    /// `accent?.accent ?: colorScheme.primary` (`SalusDateTile.kt:35`).
    static func tint(accent: FeatureAccent?, theme: SalusResolvedTheme) -> Color {
        accent?.accent ?? theme.colorScheme.primary
    }
}

/// `object SalusDateTileDefaults` (`SalusDateTile.kt:57-60`). Component dimensions, not design
/// tokens — Android keeps them in `:core:ui` too, not in `:core:designsystem`.
public enum SalusDateTileDefaults {
    /// `SalusDateTileDefaults.Width` (`SalusDateTile.kt:58`).
    public static let width: CGFloat = 56
    /// `SalusDateTileDefaults.Height` (`SalusDateTile.kt:59`).
    public static let height: CGFloat = 60
}

#Preview("Date tiles") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack {
        theme.colorScheme.surfaceContainerLow
        HStack(spacing: SalusSpacing.sm) {
            SalusDateTile(dayOfMonth: 18, monthShort: "Ağu", accent: theme.extendedColors.appointments)
            SalusDateTile(dayOfMonth: 18, monthShort: "Ağu")
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 120)
    .salusTheme(theme)
}
