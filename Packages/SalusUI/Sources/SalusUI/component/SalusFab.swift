// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusFab.kt:40-64` in its M15 shape.

import SalusDesignSystem
import SwiftUI

/// Squircle floating action button in the strong primary color. Feature screens place it in a
/// `ZStack` aligned to `.bottomTrailing`, the twin of Compose's `Box` + `Modifier.align`, per the
/// single-Scaffold rule (`SalusFab.kt:35-38`).
///
/// In dark mode the disc gets the same `accentGlow` wash as `SalusButton`'s primary variant,
/// which is what separates it from the near-black ground (`SalusFab.kt:68-69`).
public struct SalusFab: View {
    private let systemImage: String
    private let contentDescription: String?
    private let action: () -> Void

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - systemImage: SF Symbol name. Kotlin takes an `ImageVector` from `Icons`; the iOS twin of
    ///     that catalogue is SF Symbols, named rather than referenced.
    ///   - contentDescription: what VoiceOver announces (`SalusFab.kt:43`).
    public init(systemImage: String, contentDescription: String?, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.contentDescription = contentDescription
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: Self.iconSize))
                .frame(width: Self.containerSize, height: Self.containerSize)
                .foregroundStyle(theme.colorScheme.onPrimary)
                .background(background)
        }
        .buttonStyle(.plain)
        // `verbatim:` throughout: `Text(_:)` with a literal takes a `LocalizedStringKey`, and
        // Xcode's extraction writes every one it finds into this package's `Localizable.xcstrings`
        // — the empty key it added during the M2 simulator pass came from here.
        .accessibilityLabel(Text(verbatim: contentDescription ?? ""))
    }

    /// `containerColor = primary`, `shape = CircleShape` (`SalusFab.kt:52-53`) with the
    /// `accentGlow` wash underneath (`SalusFab.kt:66-69`). The glow is what separates the disc
    /// from the ground in both modes — in dark from the near-black screen, in light from the
    /// tinted background — so it is a `primary`-tinted shadow, not the neutral `salusShadow`.
    private var background: some View {
        Circle()
            .fill(theme.colorScheme.primary)
            .shadow(
                color: theme.extendedColors.accentGlow,
                radius: Self.glowRadius,
                x: 0,
                y: Self.glowOffsetY
            )
    }

    /// Material's own `FloatingActionButton` container size, which Android inherits without naming
    /// it. Not a Salus token: `design-tokens.md` has no component sizes, and inventing one here
    /// would put a value in the token layer that Android has no counterpart for. It is comfortably
    /// above `SalusTouchTarget.min`.
    private static let containerSize: CGFloat = 56
    private static let iconSize: CGFloat = 24
    /// `SalusFabDefaults.GlowElevation` (`SalusFab.kt:72`) — the spread of the accent wash.
    private static let glowRadius: CGFloat = 12
    private static let glowOffsetY: CGFloat = 4
}

/// The labelled FAB variant: a primary pill for the one action a list screen exists to offer
/// ("Add medication", "New appointment"), the twin of `SalusExtendedFab.kt:71-109`.
///
/// In dark it sits in the same `accentGlow` wash as `SalusButton`'s primary variant — the glow is
/// what separates it from the near-black ground (`SalusExtendedFab.kt:78-94`). In light there is
/// no shadow, exactly as Android draws a `tonalElevation.none` raised pill there
/// (`SalusFab.kt:93-94`).
public struct SalusExtendedFab: View {
    private let label: String
    private let systemImage: String
    private let action: () -> Void

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - label: the pill's text, in `labelLarge` (`SalusExtendedFab.kt:106`).
    ///   - systemImage: SF Symbol name — the iOS twin of the `Icons.Outlined.Add` Kotlin passes.
    ///   - action: what the tap runs.
    public init(label: String, systemImage: String, action: @escaping () -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: SalusSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: SalusFabDefaults.iconSize))
                // `Text(verbatim:)` because `label` is already a resolved string.
                Text(verbatim: label)
                    .font(SalusTypography.labelLarge.font)
                    .tracking(SalusTypography.labelLarge.tracking)
            }
            .foregroundStyle(theme.colorScheme.onPrimary)
            .padding(.horizontal, SalusSpacing.xl)
            .frame(minHeight: SalusFabDefaults.extendedHeight)
            .background(background)
            .contentShape(SalusShapes.pill)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: label))
    }

    /// `containerColor = primary`, `shape = CircleShape` (`SalusExtendedFab.kt:91-92`). The
    /// `accentGlow` shadow is what separates the labelled pill from the ground in dark mode; in
    /// light mode the wash under a saturated primary pill reads as a smudge, so it is dropped
    /// (`SalusExtendedFab.kt:85-89, 94`).
    private var background: some View {
        SalusShapes.pill
            .fill(theme.colorScheme.primary)
            .shadow(
                color: theme.extendedColors.accentGlow,
                radius: SalusFabDefaults.glowElevation,
                x: 0,
                y: 0
            )
    }
}

/// `object SalusFabDefaults` (`SalusFab.kt:111-118`) — the extended FAB's component dimensions,
/// not design tokens (Android keeps them in `:core:ui`).
public enum SalusFabDefaults {
    /// One notch under the 56 pt primary button: an overlay, not the screen's main action
    /// (`SalusFab.kt:112-113`).
    public static let extendedHeight: CGFloat = 52
    /// `SalusFabDefaults.IconSize` (`SalusFab.kt:114`).
    public static let iconSize: CGFloat = 20
    /// `SalusFabDefaults.GlowElevation` (`SalusFab.kt:117`) — the spread of the dark-mode accent
    /// wash under the pill.
    public static let glowElevation: CGFloat = 12
}

#Preview("FAB") {
    SalusPreviewPalettes {
        VStack(spacing: SalusSpacing.lg) {
            SalusFab(systemImage: "plus", contentDescription: "Add", action: {})
            SalusExtendedFab(label: "New appointment", systemImage: "plus", action: {})
        }
    }
}
