// Ported from `core/ui/.../component/SalusFab.kt:19-35`.

import SalusDesignSystem
import SwiftUI

/// Squircle floating action button in the strong primary color. Feature screens place it in a
/// `ZStack` aligned to `.bottomTrailing`, the twin of Compose's `Box` + `Modifier.align`, per the
/// single-Scaffold rule (`SalusFab.kt:15-18`).
public struct SalusFab: View {
    private let systemImage: String
    private let contentDescription: String?
    private let action: () -> Void

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - systemImage: SF Symbol name. Kotlin takes an `ImageVector` from `Icons`; the iOS twin of
    ///     that catalogue is SF Symbols, named rather than referenced.
    ///   - contentDescription: what VoiceOver announces (`SalusFab.kt:22`).
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
        .accessibilityLabel(contentDescription.map(Text.init) ?? Text(""))
    }

    /// `containerColor = primary`, `shape = MaterialTheme.shapes.medium` (`SalusFab.kt:29-31`).
    private var background: some View {
        SalusShapes.mediumShape
            .fill(theme.colorScheme.primary)
            .salusShadow(.raised, isDark: theme.isDark)
    }

    /// Material's own `FloatingActionButton` container size, which Android inherits without naming
    /// it. Not a Salus token: `design-tokens.md` has no component sizes, and inventing one here
    /// would put a value in the token layer that Android has no counterpart for. It is comfortably
    /// above `SalusTouchTarget.min`.
    private static let containerSize: CGFloat = 56
    private static let iconSize: CGFloat = 24
}

#Preview("FAB") {
    ZStack(alignment: .bottomTrailing) {
        SalusTheme.resolve(systemIsDark: false).colorScheme.background
        SalusFab(systemImage: "plus", contentDescription: "Add", action: {})
            .padding(SalusSpacing.lg)
    }
    .frame(width: 240, height: 200)
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
}
