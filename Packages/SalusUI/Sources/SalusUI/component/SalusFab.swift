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

#Preview("FAB") {
    SalusPreviewPalettes {
        SalusFab(systemImage: "plus", contentDescription: "Add", action: {})
    }
}
