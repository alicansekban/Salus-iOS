import FeatureSmoking
import SalusDesignSystem
import SalusUI
import SwiftUI

/// Presents the smoking craving flow as a full-screen cover (iOS-M17 Task 12).
///
/// Android pushes `SmokingCravingKey` onto its one back stack. Here the flow takes over the whole
/// screen, tab bar included, and has no tab to belong to — so it is a `fullScreenCover`, and there
/// is exactly ONE path to it for both callers. Main's ViewModel and Home's card both call
/// `navigator.navigate(SmokingCravingKey(…))`; `RootView.observeNavigationCommands` hands every
/// command to the module's `SmokingCravingPresenter` before any back stack, which presents the cover
/// and consumes the command (a `pop` while it is up closes the cover). Nothing in `FeatureHome` or
/// `FeatureSmoking`'s callers knows a cover exists, the same way no feature knows the paywall's.
///
/// The cover is the shell's, so the bars are painted here and not by the feature: the navigation
/// bar's ground and scheme are the ones `RootNavigationStack` gives every stack. The snackbar host is
/// repeated inside it, because the host the tabs mount sits UNDER a full-screen cover and a refused
/// write must not be reported to a screen nobody can see.
@MainActor
struct SmokingCravingHost: View {
    @Environment(AppCompositionRoot.self) private var root
    @Environment(\.salusTheme) private var theme

    /// Whether the cover is up, derived from the presenter. `fullScreenCover` has no swipe to
    /// dismiss, so the only way out is the screen's close button, which the ViewModel turns into a
    /// `pop` the presenter consumes.
    private var isPresented: Binding<Bool> {
        Binding(
            get: { root.smokingModule.cravingPresenter.presented != nil },
            set: { presented in
                if !presented {
                    root.smokingModule.cravingPresenter.dismiss()
                }
            }
        )
    }

    var body: some View {
        Color.clear
            // **Load-bearing**, for the reason `PaywallHost` spells out: an unconditional full-bleed
            // sibling at the top of `RootView`'s `ZStack` that would otherwise take every tap.
            .allowsHitTesting(false)
            .fullScreenCover(isPresented: isPresented) {
                NavigationStack {
                    CravingRoute()
                }
                .toolbarBackground(SalusBarAppearance.colors(for: theme).navigationBarGround, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(theme.isDark ? .dark : .light, for: .navigationBar)
                .overlay(alignment: .bottom) { SalusSnackbarHost(controller: root.snackbar) }
                // On the presented content, as every module is on its stack: the Route reads the
                // module out of the environment it was handed.
                .environment(\.smokingModule, root.smokingModule)
            }
    }
}
