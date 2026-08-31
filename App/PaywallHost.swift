// The shell's paywall host — the iOS twin of Android's `PaywallHost` wiring in `SalusApp.kt:138-226`.
//
// Android draws the paywall as an `AnimatedVisibility` overlay inside the app's composition; iOS
// presents it as a full-screen cover (recorded divergence (d)). What both share is that only the
// shell mounts it: `PaywallController` publishes `request` and this view turns that into a
// `.fullScreenCover`, so no feature ever knows a sheet exists — it calls `paywallController.show(_:)`
// and is done.
//
// `fullScreenCover` is the iOS answer to the paywall being "full-screen, above the tab bar, outside
// every NavigationStack": it covers the whole window including the tab bar, slides up by default
// (`cover`'s built-in bottom-up presentation) and the close button (in `PaywallSheet`) slides it back
// down. The sheet's own ViewModel is built and owned by the module the composition root injected, so
// re-presenting the cover re-uses the same ViewModel over the same controller.
//
// `PaywallRoute` reads `paywallModule` from the environment; the module lives on the root, so this
// view injects it onto the presented content — the Route cannot read `AppCompositionRoot` itself
// (that type is in this target, which the package cannot import).

import FeaturePaywall
import SalusPremium
import SalusSettings
import SwiftUI

/// Presents the paywall whenever `PaywallController.request` is non-nil, and dismisses it when the
/// controller clears the request (purchase success, restore, or the sheet's close button).
@MainActor
struct PaywallHost: View {
    /// The graph — the module that builds the paywall's ViewModel lives on it.
    @Environment(AppCompositionRoot.self) private var root

    /// Whether the cover is up, derived from `paywallController.request`. A `Bool` binding is what
    /// `fullScreenCover` and its on-dismiss closure take; the controller stays the single source of
    /// truth (`request`), and SwiftUI's own dismissal (swipe-down) is not allowed — `fullScreenCover`
    /// has no swipe to dismiss, so the only way out is the sheet's close button or a purchase.
    private var isPresented: Binding<Bool> {
        Binding(
            get: { root.paywallController.request != nil },
            set: { presented in
                if !presented, root.paywallController.request != nil {
                    root.paywallController.dismiss()
                }
            }
        )
    }

    var body: some View {
        Color.clear
            // **Load-bearing.** `Color` is hit-testable whatever its alpha — `Color.clear` is how a
            // deliberately invisible tap target is spelled — and this one is an unconditional,
            // full-bleed sibling at the top of `RootView`'s `ZStack` (the gates below it are all
            // behind an `if`). Without this it would take every tap in the app, tab bar included,
            // and nothing underneath would ever respond. The view is here to *present*, not to
            // draw or to receive.
            .allowsHitTesting(false)
            .fullScreenCover(isPresented: isPresented) {
                PaywallRoute()
                    // The module is injected here, on the presented content, exactly as every other
                    // feature module is on its stack (`FeaturePaywall`'s `@Entry` note): the Route
                    // reads `paywallModule` out of the environment it was handed.
                    .environment(\.paywallModule, root.paywallModule)
            }
    }
}
