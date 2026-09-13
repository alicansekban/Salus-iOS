// The colours the two system bars are painted with — the twin of
// `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/SalusBottomBar.kt:225-237`
// and `:313-319` (the bar ground, its hairline and the two item colours) and of
// `.../SalusTopBar.kt:125` and `:154` (the top bar's ground and title colour).
//
// iOS does not mirror either Kotlin composable: spec §2.4 / divergence (a) keep the system
// `TabView` and the system navigation bar and paint them instead. Painting is where SwiftUI runs
// out of API — there is no unselected-tab-item colour and no navigation-bar title font — so the
// two `UIKit` appearance objects are built here from the resolved theme and installed on the
// appearance proxies once per theme resolution (divergence (c)).
//
// **Two layers on purpose.** `colors(for:)` is the whole mapping and is platform-neutral;
// `tabBar(for:)` / `navigationBar(for:)` only spell it to `UIKit`. `swift test` builds this
// package for the macOS HOST, where `UITabBarAppearance` does not exist, so a mapping written
// only inside `#if canImport(UIKit)` could never be run by the test gate. The split is what
// keeps the decisions under test (`SalusBarAppearanceTests`); the `UIKit` spelling is covered by
// the iOS compile in `scripts/build-app.sh` and by the QA sheet.
//
// **Appearance-proxy timing** (spec §10), and what it took. A proxy change reaches bars created
// *after* the call, so `apply(_:)` paints the future and nothing that is already on screen. Owner
// QA round 1 confirmed the consequence on a device: a palette switch from the More sheet left the
// tab bar, the current stack's navigation bar and every pushed screen's bar on the old theme until
// a tab switch made UIKit rebuild one.
//
// The live bars are therefore repainted directly, by `SalusBarRepainter` — a zero-size view the
// shell plants, which walks the window on every theme change and installs the two appearances this
// file builds onto the bars it finds. `apply(_:)` stays exactly as it is and keeps its own half:
// bars made after the switch. Alongside both, `RootView` carries `.toolbarBackground(_, for:)` and
// `.toolbarColorScheme(_, for:)` for each bar, which is how the colours SwiftUI paints for itself
// (the title, the bar's own chrome) are told the theme moved.
//
// The recorded fallback — `.id(theme.isDark)` on the `TabView` in `RootView.tabs` — is retired
// rather than pending: it was always going to tear down and rebuild every tab's content on a theme
// switch, and there is nothing left for it to fix. `m16-manual-qa.md` §5.1 is the device check.

import SalusDesignSystem
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// How a resolved theme paints the system tab bar and navigation bar.
public enum SalusBarAppearance {
    /// The six colours the two bars are drawn from. A value rather than six functions so the
    /// mapping is one readable table and the test pins it in one place.
    public struct Colors: Equatable, Sendable {
        /// The tab bar's ground: `surfaceContainerLow` in dark, `surfaceContainerLowest` in light
        /// (`SalusBottomBar.kt:227-231`).
        public let tabBarGround: Color
        /// The hairline above the tab bar: `cardBorder` in dark, `nil` in light
        /// (`SalusBottomBar.kt:232-236`). Android's light bar is told apart by an 8 dp shadow
        /// (`:237`); a `UITabBarAppearance` has no shadow, so `nil` asks for the platform's own
        /// hairline, which is the same picture the system draws under every other iOS tab bar.
        public let tabBarShadow: Color?
        /// The selected tab item (`SalusBottomBar.kt:315-316`).
        public let selectedItem: Color
        /// The unselected tab items (`SalusBottomBar.kt:317-318`).
        public let unselectedItem: Color
        /// The navigation bar's ground (`SalusTopBar.kt:125`).
        public let navigationBarGround: Color
        /// The navigation bar's title (`SalusTopBar.kt:154`).
        public let navigationBarTitle: Color
    }

    /// The whole token mapping, as a pure function of the resolved theme.
    public static func colors(for theme: SalusResolvedTheme) -> Colors {
        Colors(
            tabBarGround: theme.isDark
                ? theme.colorScheme.surfaceContainerLow
                : theme.colorScheme.surfaceContainerLowest,
            tabBarShadow: theme.isDark ? theme.extendedColors.cardBorder : nil,
            selectedItem: theme.colorScheme.primary,
            unselectedItem: theme.colorScheme.onSurfaceVariant,
            navigationBarGround: theme.colorScheme.background,
            navigationBarTitle: theme.colorScheme.onSurface
        )
    }

    #if canImport(UIKit)
        /// The tab bar's appearance. Opaque on purpose: the default is a translucent material
        /// that samples whatever scrolls under it, which would drift off the token.
        @MainActor
        public static func tabBar(for theme: SalusResolvedTheme) -> UITabBarAppearance {
            let colors = colors(for: theme)
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(colors.tabBarGround)
            // `nil` leaves the system hairline in place — see `Colors.tabBarShadow`.
            appearance.shadowColor = colors.tabBarShadow.map(UIColor.init)

            // All three layouts, not just the stacked one: a phone in landscape lays its items out
            // inline and an iPad uses the compact-inline set, so painting one would leave the bar
            // unthemed after a rotation.
            for layout in [
                appearance.stackedLayoutAppearance,
                appearance.inlineLayoutAppearance,
                appearance.compactInlineLayoutAppearance
            ] {
                paintItems(layout, colors: colors)
            }
            return appearance
        }

        /// The navigation bar's appearance — inline titles only, so the large-title attributes
        /// exist purely to keep a stale colour from surfacing if something ever asks for them.
        @MainActor
        public static func navigationBar(for theme: SalusResolvedTheme) -> UINavigationBarAppearance {
            let colors = colors(for: theme)
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(colors.navigationBarGround)
            // The navigation bar carries no hairline of its own: its ground is `background`, the
            // same colour the content below it sits on, so a line would draw a seam where the
            // design has none.
            appearance.shadowColor = nil

            let title = UIColor(colors.navigationBarTitle)
            appearance.titleTextAttributes = [.foregroundColor: title, .font: titleFont]
            appearance.largeTitleTextAttributes = [.foregroundColor: title]
            return appearance
        }

        /// Installs both appearances on the `UIKit` proxies. Called from the shell on every theme
        /// resolution, and it covers the bars made **after** that call; the ones already on screen
        /// are ``SalusBarRepainter``'s. See the file note for why it takes both.
        @MainActor
        public static func apply(_ theme: SalusResolvedTheme) {
            let tabBarAppearance = tabBar(for: theme)
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

            let navigationBarAppearance = navigationBar(for: theme)
            UINavigationBar.appearance().standardAppearance = navigationBarAppearance
            UINavigationBar.appearance().compactAppearance = navigationBarAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
            UINavigationBar.appearance().compactScrollEdgeAppearance = navigationBarAppearance
        }

        /// Both states of one tab-item layout. Icon and title take the same colour, exactly as
        /// Kotlin's one `contentColor` drives both (`SalusBottomBar.kt:314-322`).
        @MainActor
        private static func paintItems(_ layout: UITabBarItemAppearance, colors: Colors) {
            let selected = UIColor(colors.selectedItem)
            let unselected = UIColor(colors.unselectedItem)
            layout.selected.iconColor = selected
            layout.selected.titleTextAttributes = [.foregroundColor: selected]
            layout.normal.iconColor = unselected
            layout.normal.titleTextAttributes = [.foregroundColor: unselected]
        }

        /// The title role, read from the token rather than typed here: `titleMedium`, whose weight
        /// is `.semibold` (`SalusTypography.swift`, §9.1). `Font.Weight` has no bridge to
        /// `UIFont.Weight`, so the one role a bar draws is the one place the weight is spelled
        /// twice — and the size still comes from the token, so a metric change moves it.
        @MainActor
        private static var titleFont: UIFont {
            UIFont.systemFont(ofSize: SalusTypography.titleMedium.size, weight: .semibold)
        }
    #endif
}
