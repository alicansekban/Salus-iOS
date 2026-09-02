// The shell's half of the live language switch — the iOS twin of appcompat recreating the
// activity after `setApplicationLocales` (`AppCompatLocaleController.kt`).
//
// `SalusLocalization` (SalusCommon) is what every `…Strings` helper resolves through, and
// `SalusLocaleState` is its main-actor mirror. Reading the mirror in a `body` is what makes the
// change re-render: `.id` gives the tabs a new identity per language, so every screen inside them
// is rebuilt in the new language, and `\.locale` carries the pick to the date and number formatting
// every feature does through `@Environment(\.locale)` (the twin of
// `LocalLocale.current.platformLocale`).
//
// Only the tabs take the new identity. `RootView`'s own `@State` — `backStacks` above all — is
// untouched, so the selected tab and each pushed screen survive the switch, exactly as Android's
// saved instance state does across `recreate()`. The gates and the paywall sit outside the tabs and
// are transient: they are rebuilt in the new language the next time they show.

import SalusCommon
import SwiftUI

extension View {
    /// Re-identifies the view — and sets its `\.locale` — whenever the in-app language pick changes.
    func liveLocale() -> some View {
        modifier(LiveLocaleModifier())
    }
}

private struct LiveLocaleModifier: ViewModifier {
    private let localeState = SalusLocaleState.shared

    func body(content: Content) -> some View {
        content
            .id(localeState.languageCode ?? "system")
            .environment(\.locale, localeState.locale ?? .current)
    }
}
