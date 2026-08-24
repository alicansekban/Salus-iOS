import FeatureSettings
import FeatureVitals
import SalusDesignSystem
import SalusModel
import SalusNavigation
import SalusUI
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
///  4. **It mounts the app's one snackbar host** (`SalusApp.kt:106-136`) — over the selected tab's
///     content, above the tab bar — so an undo survives the screen the delete was triggered from.
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
        // A reminder tapped while the app was closed arrives before this view exists, so the ref
        // waits in the router and this reads it on the first update as well as on later taps.
        .onChange(of: root.reminderOpenRouter.pending, initial: true) { _, _ in openTappedReminder() }
        .task { await observeThemeMode() }
        .task { await observeNavigationCommands() }
        .task { await root.logSeededProfile() }
    }

    /// One stack per tab. No `navigationDestination` written here on purpose: `TabBackStacks.push`
    /// puts the feature's **concrete** key into the path, so each feature package registers its own
    /// `navigationDestination(for:)` in a `…Destinations()` modifier applied here — the twin of
    /// Android's `vitalsEntries` / `homeEntries` `NavEntry` providers. The shell therefore never
    /// names a key; `vitalsDestinations()` and `settingsDestinations()` below are those modifiers,
    /// and the three remaining tabs keep their placeholder until their feature lands.
    private func tabStack(for tab: RootTab) -> some View {
        navigationStack(for: tab)
            // The app's one snackbar host, applied *inside* the tab's content region rather than
            // over the whole window. That placement is the whole fix: the tab bar's inset exists
            // only in here, so an overlay laid out against it lands above the bar (and above the
            // home indicator, in either orientation) — the position Compose's `Scaffold` gives
            // `SnackbarHost` above the `NavigationBar`. Over the window it landed *in* the tab-bar
            // band, hid it, and swallowed tab taps with its own dismiss gesture.
            .overlay(alignment: .bottom) { snackbarHost(for: tab) }
    }

    /// Exactly one host exists at a time: `backStacks.selection` is a single value, so the four
    /// unselected tabs build the empty branch. That keeps the shell rule ("one host, mounted by the
    /// shell") while still letting the host sit inside a tab's safe area — the two properties are
    /// otherwise in conflict, because the only place that knows the tab-bar inset is a tab.
    ///
    /// The controller lives on `AppCompositionRoot`, not here, so switching tabs mid-undo re-creates
    /// this view without touching the queue: the snackbar keeps its remaining time and its action,
    /// and only replays its entrance transition in the tab that now shows it.
    @ViewBuilder
    private func snackbarHost(for tab: RootTab) -> some View {
        if tab == backStacks.selection {
            SalusSnackbarHost(controller: root.snackbar)
        }
    }

    @ViewBuilder
    private func navigationStack(for tab: RootTab) -> some View {
        switch tab {
        case .vitals:
            NavigationStack(path: backStacks.binding(for: tab)) {
                VitalsRoute(onOpenTrends: {
                    // TODO(M11): trends is another feature's screen, whose key this shell cannot
                    // name yet. Cross-feature navigation is a shell callback (spec §4), so when
                    // `FeatureTrends` lands this pushes its key through `root.navigator`.
                })
                .vitalsDestinations()
            }
            // Applied to the stack, not inside its root: a pushed `WeightEditorKey` destination is
            // rendered by the stack, so an environment value set on the root view would not reach
            // the editor.
            .environment(\.vitalsModule, root.vitalsModule)

        case .more:
            NavigationStack(path: backStacks.binding(for: tab)) {
                // TODO(M8): the settings hub replaces this placeholder. Until it lands the tab's
                // root carries the one row this milestone needs, so Reminder Health is reachable
                // rather than only routable.
                PlaceholderScreen(tab: tab) {
                    root.navigator.navigate(ReminderHealthKey())
                }
                .settingsDestinations()
            }
            // On the stack, not inside its root — a pushed `ReminderHealthKey` destination is
            // rendered by the stack, so an environment value set on the root would not reach it.
            .environment(\.settingsModule, root.settingsModule)

        default:
            NavigationStack(path: backStacks.binding(for: tab)) {
                PlaceholderScreen(tab: tab)
            }
        }
    }

    /// Shows the tab that owns a tapped reminder — the whole of iOS-M3's deep link. Pushing the
    /// occurrence's own screen needs a navigation key per reminder type, which lands with M4/M5.
    private func openTappedReminder() {
        guard let ref = root.reminderOpenRouter.consume() else { return }
        backStacks.switchTopLevel(RootTab.hosting(ref.type))
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
