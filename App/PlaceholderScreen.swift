import SalusDesignSystem
import SwiftUI

/// A tab's empty destination, painted entirely from tokens.
///
/// The rule this view exists to demonstrate, and the one every real screen will inherit: no
/// literal colors, no literal spacing, no literal corner radii, no literal font sizes. Colors
/// come from the resolved `SalusColorScheme`, spacing from `SalusSpacing`, radii from
/// `SalusShapes`, type from `SalusTypography`. A screen that needs a value none of those
/// provide needs a token added to `design-tokens.md` first, not a number added here.
struct PlaceholderScreen: View {
    let tab: RootTab
    let theme: SalusResolvedTheme

    private var colors: SalusColorScheme { theme.colorScheme }

    var body: some View {
        ZStack {
            colors.background
                .ignoresSafeArea()
            card
        }
    }

    private var card: some View {
        VStack(spacing: SalusSpacing.sm) {
            icon
            title
            subtitle
        }
        .frame(maxWidth: .infinity)
        .padding(SalusSpacing.xl)
        .background(cardSurface)
        .padding(SalusSpacing.lg)
    }

    private var icon: some View {
        Image(systemName: tab.symbolName)
            .font(SalusTypography.headlineMedium.font)
            .foregroundStyle(colors.primary)
            .frame(height: SalusTouchTarget.min)
    }

    private var title: some View {
        Text(tab.placeholderLabel)
            .font(SalusTypography.headlineSmall.font)
            .tracking(SalusTypography.headlineSmall.tracking)
            .foregroundStyle(colors.onSurface)
    }

    private var subtitle: some View {
        Text(Self.placeholderBody)
            .font(SalusTypography.bodyMedium.font)
            .tracking(SalusTypography.bodyMedium.tracking)
            .foregroundStyle(colors.onSurfaceVariant)
            .multilineTextAlignment(.center)
    }

    /// The card itself: a `surfaceContainer` fill on the `background`, outlined so the two
    /// surfaces stay distinguishable in both themes rather than only in the light one.
    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: SalusShapes.large, style: .continuous)
            .fill(colors.surfaceContainer)
            .overlay(cardBorder)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: SalusShapes.large, style: .continuous)
            .strokeBorder(colors.outlineVariant, lineWidth: Self.hairline)
    }

    /// Placeholder copy, not a user-facing string: M0 does no strings work, and this text is
    /// expected to be deleted rather than localized when the tab gets real content.
    private static let placeholderBody = "M0 shell — this tab has no content yet."

    /// A one-point outline. Not a token: `design-tokens.md` carries no stroke widths, so
    /// inventing a `SalusStroke` namespace to hold a single hairline would put a value in the
    /// token layer that Android has no counterpart for.
    private static let hairline: CGFloat = 1
}

#Preview("Light") {
    PlaceholderScreen(tab: .home, theme: SalusTheme.resolve(systemIsDark: false))
}

#Preview("Dark") {
    PlaceholderScreen(tab: .vitals, theme: SalusTheme.resolve(systemIsDark: true))
}
