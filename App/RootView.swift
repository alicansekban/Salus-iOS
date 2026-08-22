import SalusDesignSystem
import SalusModel
import SalusNavigation
import SwiftUI

/// The five-tab shell — the iOS twin of `app/src/main/kotlin/com/alicansekban/salus/ui/SalusApp.kt`.
///
/// It owns three jobs, exactly as the Compose shell does:
///
///  1. **It is the only thing that mutates the back stack.** `Navigator` publishes commands; this
///     view applies them to `TabBackStacks` (`SalusApp.kt:89-99`).
///  2. **It resolves the theme once**, from the stored mode and the system appearance, and injects
///     it — the `MaterialTheme(...)` wrapper of `Theme.kt:99-104`, spelled as an environment value.
///  3. **It hosts one navigation stack per tab.** Android flattens its per-tab stacks into the one
///     list `NavDisplay` renders; SwiftUI gives each tab its own `NavigationStack`.
///
/// `@MainActor` on the struct rather than only on `body`: `TabBackStacks` is a main-actor
/// `@Observable`, and a stored-property initializer runs outside `body`'s isolation.
@MainActor
struct RootView: View {
    /// The graph `SalusApp` built and injected. Nothing here reaches for a global.
    @Environment(AppCompositionRoot.self) private var root

    /// What the OS currently reports — the iOS shape of Compose's `isSystemInDarkTheme()`, which is
    /// what Android's `SalusTheme` defaults `darkTheme` to (`Theme.kt:87`).
    @Environment(\.colorScheme) private var systemColorScheme

    /// One `NavigationPath` per tab, so a tab switch preserves what was pushed inside each
    /// (`SalusApp.kt:87`: `remember { TopLevelBackStack(HomeKey) }`).
    @State private var backStacks = TabBackStacks<RootTab>(initial: .home)

    /// The stored `theme_mode`, mirrored out of `SalusPreferencesDataSource` by the `.task` below.
    /// Seeded with the same default the store returns before anything has been written.
    @State private var themeMode: ThemeMode = .default

    /// `Theme.kt:99-104`. The premium palette is pinned to `.classic` until M9 wires entitlement:
    /// the stored `premium_theme` is what the user *selected*, and `SalusTheme.resolve` wants what
    /// they are *entitled* to — a distinction there is nothing to evaluate against yet.
    private var theme: SalusResolvedTheme {
        SalusTheme.resolve(
            mode: themeMode,
            premiumTheme: .classic,
            systemIsDark: systemColorScheme == .dark
        )
    }

    /// The tab-bar selection, written through `switchTopLevel` — the holder's `selection` is
    /// `private(set)`, so that method is the only door, exactly as `TopLevelBackStack.topLevelKey`
    /// moves only through Kotlin's `switchTopLevel` (`TopLevelBackStack.kt:18, 30-35`). A press on
    /// the tab that is already selected changes nothing, on both platforms.
    private var selection: Binding<RootTab> {
        Binding(
            get: { backStacks.selection },
            set: { backStacks.switchTopLevel($0) }
        )
    }

    var body: some View {
        TabView(selection: selection) {
            ForEach(RootTab.allCases) { tab in
                tabStack(for: tab)
                    .tabItem { Label(tab.placeholderLabel, systemImage: tab.symbolName) }
                    .tag(tab)
            }
        }
        // The selected tab's accent. `primary` rather than a hand-picked highlight, so a premium
        // palette repaints the tab bar for free the moment entitlement is wired up: `primary` is
        // one of the eight roles `withPremiumAccent` swaps.
        .tint(theme.colorScheme.primary)
        // Android's `NavigationBar` sits on `surfaceContainer` by default; pin the same role here
        // instead of inheriting the platform's translucent material, which would sample whatever is
        // behind it and drift from the token.
        .toolbarBackground(theme.colorScheme.surfaceContainer, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        // Resolved once, read everywhere below — no screen takes a `theme:` parameter.
        .salusTheme(theme)
        // `nil` for `.system`, which leaves the window to the OS (`ThemeMode.preferredColorScheme`).
        .preferredColorScheme(themeMode.preferredColorScheme)
        .task { await observeThemeMode() }
        .task { await observeNavigationCommands() }
        .task { await root.logSeededProfile() }
    }

    private func tabStack(for tab: RootTab) -> some View {
        NavigationStack(path: backStacks.binding(for: tab)) {
            PlaceholderScreen(tab: tab)
                .navigationDestination(for: AnyNavKey.self) { key in
                    PushedKeyPlaceholder(key: key)
                }
        }
    }

    /// The store emits its current value first, then every change, so this both seeds and tracks.
    private func observeThemeMode() async {
        for await settings in root.preferences.userSettings {
            themeMode = settings.themeMode
        }
    }

    /// `SalusApp.kt:92-99`, one for one: `Navigate` pushes, `Pop` pops, and nothing else in the app
    /// touches the stack.
    private func observeNavigationCommands() async {
        for await command in root.navigator.commands {
            switch command {
            case let .navigate(key): backStacks.push(key)
            case .pop: backStacks.pop()
            }
        }
    }
}

/// What a pushed key draws until the feature that owns it lands.
///
/// M1 ships the navigation plumbing, not destinations: no feature declares a key yet, so this is
/// reachable only from a test or a future push. It exists so `navigationDestination` is registered
/// from the start — a stack whose destination is missing pushes a blank screen and logs nothing.
private struct PushedKeyPlaceholder: View {
    let key: AnyNavKey

    @Environment(\.salusTheme) private var theme

    var body: some View {
        ZStack {
            theme.colorScheme.background
                .ignoresSafeArea()
            Text(String(describing: key.base))
                .font(SalusTypography.bodyMedium.font)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .padding(SalusSpacing.lg)
        }
    }
}

#Preview("Light") {
    RootView()
        .environment(AppCompositionRoot())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    RootView()
        .environment(AppCompositionRoot())
        .preferredColorScheme(.dark)
}
