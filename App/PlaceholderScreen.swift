import FeatureSettings
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

    /// Pushes Reminder Health, on the one tab that has a screen to reach.
    ///
    /// TODO(M8): delete this along with the whole view. Reminder Health is a row on the settings
    /// hub (`SettingsScreen.kt`), and the hub is M8; until it exists the row lives here, because a
    /// screen nothing can open is a screen nobody has looked at.
    var onOpenReminderHealth: (() -> Void)?

    /// Read, not passed. The shell resolves the theme once and injects it (`RootView.salusTheme`),
    /// the way every composable below Android's `MaterialTheme(...)` reads `MaterialTheme.colorScheme`
    /// rather than taking it as a parameter.
    @Environment(\.salusTheme) private var theme

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
            if let onOpenReminderHealth {
                reminderHealthRow(onOpenReminderHealth)
            }
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

    /// The one real destination this placeholder can reach. Its label is the screen's own title,
    /// read from `FeatureSettings`' bundle rather than restated here — a feature never has its
    /// strings copied into the shell.
    private func reminderHealthRow(_ onOpen: @escaping () -> Void) -> some View {
        Button(action: onOpen) {
            Label(SettingsStrings.reminderHealthTitle, systemImage: "bell.badge")
                .font(SalusTypography.labelLarge.font)
                .tracking(SalusTypography.labelLarge.tracking)
        }
        .buttonStyle(.borderedProminent)
        .tint(colors.primary)
        .padding(.top, SalusSpacing.sm)
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

    /// Placeholder copy, not a user-facing string: strings work has not started, and this text is
    /// expected to be deleted rather than localized when the tab gets real content.
    private static let placeholderBody = "Shell — this tab has no content yet."

    /// A one-point outline. Not a token: `design-tokens.md` carries no stroke widths, so
    /// inventing a `SalusStroke` namespace to hold a single hairline would put a value in the
    /// token layer that Android has no counterpart for.
    private static let hairline: CGFloat = 1
}

#Preview("Light") {
    PlaceholderScreen(tab: .home)
        .salusTheme(SalusTheme.resolve(systemIsDark: false))
}

#Preview("More, with the Reminder Health row") {
    PlaceholderScreen(tab: .more, onOpenReminderHealth: {})
        .salusTheme(SalusTheme.resolve(systemIsDark: false))
}

#Preview("Dark") {
    PlaceholderScreen(tab: .vitals)
        .salusTheme(SalusTheme.resolve(systemIsDark: true))
}
