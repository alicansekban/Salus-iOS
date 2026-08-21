import SalusDesignSystem
import SwiftUI

/// The five-tab shell.
///
/// Empty by design — M0 ships the frame and the theming, and the features fill the tabs in
/// later milestones. What this view is actually proving is that the token layer and the theme
/// resolution built in Tasks 3 and 4 reach a running app: every color below is a resolved
/// token, none is a literal.
struct RootView: View {
    /// What the OS currently reports.
    ///
    /// This is the iOS shape of Compose's `isSystemInDarkTheme()`, which is what Android's
    /// `SalusTheme` defaults `darkTheme` to (`Theme.kt:87`).
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var selection: RootTab = .home

    /// The theme, resolved from the current system appearance.
    ///
    /// Both defaults are taken deliberately: `SalusTheme.resolve` defaults `mode` to
    /// `ThemeMode.system` and `premiumTheme` to `PremiumTheme.classic`, which is exactly the
    /// M0 contract — dark mode follows the system, the free brand palette is drawn.
    ///
    /// Because the mode is `.system`, `ThemeMode.preferredColorScheme` is `nil`, so applying
    /// it to the window would be a no-op; the shell therefore applies nothing and lets the OS
    /// decide. That is also why this file imports no `SalusModel`: with both defaults taken,
    /// the shell names neither enum, and the app target links `SalusDesignSystem` alone. When
    /// `SalusSettings` arrives in M1, the stored mode comes from `AppCompositionRoot` and
    /// `.preferredColorScheme(mode.preferredColorScheme)` starts doing real work.
    private var theme: SalusResolvedTheme {
        SalusTheme.resolve(systemIsDark: systemColorScheme == .dark)
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(RootTab.allCases) { tab in
                PlaceholderScreen(tab: tab, theme: theme)
                    .tabItem { Label(tab.placeholderLabel, systemImage: tab.symbolName) }
                    .tag(tab)
            }
        }
        // The selected tab's accent. `primary` rather than a hand-picked highlight, so a
        // premium palette repaints the tab bar for free the moment entitlement is wired up:
        // `primary` is one of the eight roles `withPremiumAccent` swaps.
        .tint(theme.colorScheme.primary)
        // Android's `NavigationBar` sits on `surfaceContainer` by default; pin the same role
        // here instead of inheriting the platform's translucent material, which would sample
        // whatever is behind it and drift from the token.
        .toolbarBackground(theme.colorScheme.surfaceContainer, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

#Preview("Light") {
    RootView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    RootView()
        .preferredColorScheme(.dark)
}
