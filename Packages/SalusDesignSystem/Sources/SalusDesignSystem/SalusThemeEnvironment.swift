// The iOS twin of Compose's `MaterialTheme` CompositionLocal
// (`core/designsystem/src/main/kotlin/com/alicansekban/salus/core/designsystem/theme/Theme.kt:85-105`,
// which wraps the app in `MaterialTheme(colorScheme = …)` and lets every composable below read
// `MaterialTheme.colorScheme` without being handed it).
//
// Compose gives that away for free; SwiftUI needs an `EnvironmentKey` declared by hand. Without one
// the resolved theme has to be threaded through every view as a parameter — which is what M0's
// `PlaceholderScreen(tab:theme:)` did, and what the M0 review flagged as the thing to fix before
// the first real screen inherits the shape.
//
// This is not a view, so `SalusDesignSystem` stays tokens-only (CLAUDE.md): it is the *access path*
// to the tokens, which is exactly where Android puts its own.

import SwiftUI

extension EnvironmentValues {
    // The resolved theme every Salus view draws from.
    //
    // Read it (`@Environment(\.salusTheme) private var theme`) rather than taking a `theme:`
    // parameter: the shell resolves the mode once, and a screen three pushes deep gets the same
    // value without four intermediate views naming it.
    //
    // The default — light, classic — is the same pair `SalusTheme.resolve`'s own defaults produce,
    // so a view rendered outside any `salusTheme(_:)` (a preview, a snapshot host) still draws real
    // tokens instead of Apple's palette.
    //
    // `@Entry` rather than a hand-written `EnvironmentKey`: SwiftFormat's `environmentEntry` rule
    // rewrites the long form to this one, so writing the long form would fail `swiftformat --lint`.
    @Entry public var salusTheme: SalusResolvedTheme = SalusTheme.resolve(systemIsDark: false)
}

extension View {
    /// Injects `theme` for this view and everything below it. Applied once, by the shell.
    public func salusTheme(_ theme: SalusResolvedTheme) -> some View {
        environment(\.salusTheme, theme)
    }
}
