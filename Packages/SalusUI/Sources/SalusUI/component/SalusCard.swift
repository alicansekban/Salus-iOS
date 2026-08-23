// Ported from `core/ui/.../component/SalusCard.kt:25-58`.

import SalusDesignSystem
import SwiftUI

/// The brand card: white in light theme, dark grey in dark theme, 24pt corners and a small
/// shadow so it visibly lifts off the tinted screen background. Feature screens use this
/// instead of a hand-rolled rounded rectangle so every card in the app shares one look
/// (`SalusCard.kt:20-24`).
public struct SalusCard<Content: View>: View {
    private let onTap: (() -> Void)?
    private let contentPadding: CGFloat
    private let content: Content

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - onTap: Kotlin's `onClick` (`SalusCard.kt:28`). `nil` is the non-interactive card, which
    ///     Compose expresses by choosing the `Card` overload without an `onClick`.
    ///   - contentPadding: Kotlin takes `PaddingValues`, which can differ per edge; every call site
    ///     in the app passes one uniform value, so this takes the value rather than four of them.
    public init(
        onTap: (() -> Void)? = nil,
        contentPadding: CGFloat = SalusSpacing.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.onTap = onTap
        self.contentPadding = contentPadding
        self.content = content()
    }

    public var body: some View {
        if let onTap {
            Button(action: onTap) { surface }
                // `.plain`, or the whole card would take the tint and the pressed styling that
                // Compose's `Card(onClick =)` does not apply either.
                .buttonStyle(.plain)
        } else {
            surface
        }
    }

    private var colors: SalusColorScheme { theme.colorScheme }

    private var surface: some View {
        // `Column` with no `verticalArrangement` is zero spacing; the content brings its own.
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(contentPadding)
            .foregroundStyle(colors.onSurface)
            .background(background)
    }

    /// `surfaceContainerLow` + `MaterialTheme.shapes.large` + `SalusElevation.card`
    /// (`SalusCard.kt:32-37`). The shadow is `design-tokens.md` §7's translation of the 2dp step;
    /// in dark mode it is dropped, because a black shadow on a `#0A0F0C` ground is invisible and
    /// Android carries the elevation as a tonal tint there instead.
    private var background: some View {
        SalusShapes.largeShape
            .fill(colors.surfaceContainerLow)
            .salusShadow(.card, isDark: theme.isDark)
    }
}

#Preview("Card") {
    VStack(spacing: SalusSpacing.lg) {
        SalusCard {
            Text("Card title")
                .font(SalusTypography.titleMedium.font)
            Text("Supporting content sits on a card that lifts off the tinted background.")
                .font(SalusTypography.bodyMedium.font)
        }
        SalusCard(onTap: {}, contentPadding: SalusSpacing.md, content: {
            Text("Tappable, tighter padding")
                .font(SalusTypography.bodyMedium.font)
        })
    }
    .padding(SalusSpacing.lg)
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
}
