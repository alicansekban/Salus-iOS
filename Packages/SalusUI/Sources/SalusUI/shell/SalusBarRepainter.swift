// The LIVE half of `SalusBarAppearance`, and the answer to spec §10's "appearance rebuild timing"
// risk — which owner QA round 1 found to be real.
//
// `SalusBarAppearance.apply(_:)` installs the two appearance objects on `UITabBar.appearance()` and
// `UINavigationBar.appearance()`. A `UIAppearance` proxy is consulted when a bar is **created**, so
// it paints every bar the app makes from that moment on and none of the ones already on screen.
// After launch there is exactly one `UITabBar` and one `UINavigationBar` per tab, all of them made
// once and kept — so switching palette from the More sheet left every visible bar, and every bar of
// every pushed screen, holding the old theme until UIKit happened to rebuild one (which a tab
// switch does, which is why the bars looked "fixed" the moment the user touched the tab bar).
//
// This file repaints those existing bars. It does not replace the proxy: the proxy is still what
// paints a bar created *later* (a sheet presented after the switch, a stack pushed after it), and
// `RootView` still calls `apply(_:)` on every theme resolution. The two together are the whole
// story — proxy for the future, this walk for the present.
//
// **Why a `UIViewRepresentable` and not a function call.** The walk needs a `UIWindow`, and SwiftUI
// has no accessor for one; a view planted in the hierarchy has `window`. It also needs to run on
// every theme change without the shell remembering to call it, which is exactly what
// `updateUIView` is: the theme is a property of the representable, so SwiftUI re-runs it whenever
// the theme differs.
//
// **Why the public type is a `View` and the representable is private.** `SalusUI` builds for the
// macOS host that runs `swift test` (`CLAUDE.md`), where `UIViewRepresentable` does not exist at
// all. A public `SalusBarRepainter: UIViewRepresentable` would therefore be missing from half the
// builds of this package. Wrapping it keeps one public spelling on both platforms — `EmptyView` on
// the host — and keeps the zero size and the accessibility opt-out inside the component, where
// they are part of what it is rather than something a caller has to remember.
//
// **What is under test and what is not.** `SalusBarTree.flatten(from:children:)` is the decision —
// depth-first, every node, the presentation chain included — and it is generic over the node so it
// can be exercised on the macOS host (`SalusBarRepainterTests`). Everything below the
// `#if canImport(UIKit)` line touches `UIKit` types that do not exist on that host and therefore
// cannot be run by `scripts/test-packages.sh` at all; it is covered by the iOS compile in
// `scripts/build-app.sh` and by `docs/qa/m16-manual-qa.md` §5.1. The split is the one
// `SalusBarAppearance` already makes, for the same reason.

import SalusDesignSystem
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// Flattening a view tree, with the `UIKit` types left out so the walk itself is testable on the
/// macOS host.
enum SalusBarTree {
    /// Every node at or below `root`, depth-first and parents before children.
    ///
    /// Generic over the node and its `children` rather than written against `UIView`: the order and
    /// the completeness are the decision worth pinning, and neither needs `UIKit` to be true.
    static func flatten<Node>(from root: Node, children: (Node) -> [Node]) -> [Node] {
        [root] + children(root).flatMap { flatten(from: $0, children: children) }
    }
}

#if canImport(UIKit)
    /// Repaints the bars that already exist, which the appearance proxies cannot reach.
    @MainActor
    enum SalusLiveBarPainter {
        /// Paints every `UITabBar` and `UINavigationBar` currently in `window` — including the ones
        /// inside anything it has presented — with the appearances ``SalusBarAppearance`` builds.
        static func repaint(_ window: UIWindow, with theme: SalusResolvedTheme) {
            let colors = SalusBarAppearance.colors(for: theme)
            let tabBarAppearance = SalusBarAppearance.tabBar(for: theme)
            let navigationBarAppearance = SalusBarAppearance.navigationBar(for: theme)
            // Both bars tint their items with the palette's `primary`: it is the value
            // `colors(for:)` already maps as the selected tab item (`SalusBottomBar.kt:315-316`)
            // and the one `RootView`'s `.tint(theme.colorScheme.primary)` hands the whole
            // `TabView`, so reading it from the same mapping is what keeps a live repaint and a
            // fresh bar the same colour.
            let itemTint = UIColor(colors.selectedItem)
            let unselectedItemTint = UIColor(colors.unselectedItem)

            for view in views(in: window) {
                if let tabBar = view as? UITabBar {
                    tabBar.standardAppearance = tabBarAppearance
                    tabBar.scrollEdgeAppearance = tabBarAppearance
                    tabBar.tintColor = itemTint
                    tabBar.unselectedItemTintColor = unselectedItemTint
                    tabBar.setNeedsLayout()
                } else if let navigationBar = view as? UINavigationBar {
                    navigationBar.standardAppearance = navigationBarAppearance
                    navigationBar.compactAppearance = navigationBarAppearance
                    navigationBar.scrollEdgeAppearance = navigationBarAppearance
                    navigationBar.compactScrollEdgeAppearance = navigationBarAppearance
                    navigationBar.tintColor = itemTint
                    navigationBar.setNeedsLayout()
                }
            }
        }

        /// The window's whole view tree, plus the tree of everything down its presentation chain.
        ///
        /// The chain is not redundant paranoia: the theme sheet is *presented* while the user taps
        /// a palette row, so its own navigation bar is one of the bars that has to repaint, and
        /// whether a presented controller's view sits inside the presenter's window tree is the
        /// presentation style's business rather than something to rely on. Walking both costs one
        /// extra pass over a handful of views, and painting a bar twice is idempotent.
        private static func views(in window: UIWindow) -> [UIView] {
            var found = SalusBarTree.flatten(from: window) { $0.subviews }
            var presented = window.rootViewController?.presentedViewController
            while let controller = presented {
                if let view = controller.viewIfLoaded {
                    found += SalusBarTree.flatten(from: view) { $0.subviews }
                }
                presented = controller.presentedViewController
            }
            return found
        }
    }

    /// The zero-size view the representable plants, which is what owns a `window` to walk from.
    ///
    /// It repaints on two occasions and needs both. `updateUIView` runs before SwiftUI has put the
    /// view into a window, so `window` is nil on the first one and the launch theme would never
    /// reach the live bars; `didMoveToWindow` is when it does, and by then the theme is already
    /// stored here.
    @MainActor
    private final class SalusBarProbeView: UIView {
        private var theme: SalusResolvedTheme?

        /// Repaints only when the theme actually moved: `updateUIView` runs on every shell update,
        /// and a full walk of the view tree per update would be a cost with nothing to show for it.
        func apply(_ theme: SalusResolvedTheme) {
            guard theme != self.theme else { return }
            self.theme = theme
            repaint()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            repaint()
        }

        private func repaint() {
            guard let theme, let window else { return }
            SalusLiveBarPainter.repaint(window, with: theme)
        }
    }

    /// The representable itself. Private: ``SalusBarRepainter`` is the spelling that exists on both
    /// platforms.
    private struct SalusBarProbe: UIViewRepresentable {
        let theme: SalusResolvedTheme

        func makeUIView(context _: Context) -> UIView {
            SalusBarProbeView()
        }

        func updateUIView(_ uiView: UIView, context _: Context) {
            (uiView as? SalusBarProbeView)?.apply(theme)
        }
    }
#endif

/// Repaints the system bars that are **already on screen** when the theme changes.
///
/// The shell plants exactly one of these, beside the `TabView` rather than inside it, and hands it
/// the resolved theme; everything else is this component's. It draws nothing, measures nothing,
/// announces nothing and cannot be tapped — see the file note for why it is a view at all and why
/// the appearance proxies are still needed alongside it.
public struct SalusBarRepainter: View {
    private let theme: SalusResolvedTheme

    public init(theme: SalusResolvedTheme) {
        self.theme = theme
    }

    public var body: some View {
        #if canImport(UIKit)
            SalusBarProbe(theme: theme)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        #else
            // The macOS host that runs `swift test` has no `UIViewRepresentable` and no bars to
            // repaint; the shell's one call site still compiles.
            EmptyView()
        #endif
    }
}
