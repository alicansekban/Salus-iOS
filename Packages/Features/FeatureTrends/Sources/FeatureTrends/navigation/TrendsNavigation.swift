// Ported from `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/
// navigation/TrendsNavigation.kt`.
//
// `EntryProviderScope<NavKey>.trendsEntries()` builds the feature's `NavEntry`s inside the
// shell's one `NavDisplay`; the iOS twin is a `View` modifier that registers the feature's
// `navigationDestination(for:)` on the shell's `NavigationStack`. Both keep every key inside the
// feature that owns it: the shell names none of them, it just applies the modifier.
//
// `@Serializable` has no twin. Navigation 3 serialises keys to survive process death; a
// `NavigationPath` only serialises when its entries were appended through the `Codable`-constrained
// overload, and nothing in this tree restores a path yet (`AnyNavKey.swift`'s note). `Hashable`
// is what `NavigationPath` and `navigationDestination(for:)` actually require.
//
// `SalusTransitions.push` (`TrendsNavigation.kt:21`) has no twin either: a `NavigationStack`
// push already animates that way, where Navigation 3 has to be told.

import SwiftUI

/// The premium trends screen, pushed on top of whichever tab it was opened from — More and
/// Vitals today (`TrendsNavigation.kt:15-18`).
///
/// It is not a tab root, so it carries the push transition and the shell hides the bottom bar
/// for it automatically. The key stays in this module: the two entry points reach it through a
/// shell callback rather than by importing it, which is what keeps cross-feature navigation
/// impossible by construction.
public struct TrendsKey: Hashable, Sendable {
    public init() {}
}

extension View {
    /// Registers every destination this feature owns (`TrendsNavigation.kt:20-24`).
    ///
    /// Applied by the shell to the vitals and More `NavigationStack`s, which are the two stacks
    /// that can push `TrendsKey`. `TrendsRoute` is not a tab root, so this is the only key the
    /// feature names.
    public func trendsDestinations() -> some View {
        navigationDestination(for: TrendsKey.self) { _ in
            TrendsRoute()
        }
    }
}
