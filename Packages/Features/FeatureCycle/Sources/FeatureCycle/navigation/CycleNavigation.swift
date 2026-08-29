// Ported from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/
// navigation/CycleNavigation.kt`.
//
// `EntryProviderScope<NavKey>.cycleEntries()` builds the feature's `NavEntry`s inside the shell's
// one `NavDisplay`; the iOS twin is a `View` modifier that registers the feature's
// `navigationDestination(for:)` on the shell's `NavigationStack`. Both keep every key inside the
// feature that owns it: the shell names none of them, it just applies the modifier.
//
// `@Serializable` has no twin. Navigation 3 serialises keys to survive process death; a
// `NavigationPath` only serialises when its entries were appended through the `Codable`-constrained
// overload, and nothing in this tree restores a path yet (`AnyNavKey.swift`'s note). `Hashable`
// is what `NavigationPath` and `navigationDestination(for:)` actually require.
//
// `SalusTransitions.push` (`CycleNavigation.kt:17, 20`) has no twin either: a `NavigationStack`
// push already animates that way, where Navigation 3 has to be told.
//
// **The payload key is spelled `epochDay`, Android's own name** — the house rule that renames
// `<noun>Id` to `id` (`MedicationsNavigation.swift:17-20`) does not apply, because an epoch day is
// not an identifier of a `CycleDay` row; it is the day itself (iOS-M6 divergence (g)).

import SwiftUI

/// The cycle calendar (`CycleNavigation.kt:10-11`).
///
/// Unlike `MedicationsKey` this one is really pushed: cycle has no tab of its own in v1, so the
/// More list and a tapped cycle reminder both reach it by pushing this key onto the stack they are
/// already in (iOS-M6 ruling 2).
public struct CycleKey: Hashable, Sendable {
    public init() {}
}

/// One day's log (`CycleNavigation.kt:13-14`).
public struct CycleDayKey: Hashable, Sendable {
    public let epochDay: Int

    public init(epochDay: Int) {
        self.epochDay = epochDay
    }
}

extension View {
    /// Registers every destination this feature owns (`CycleNavigation.kt:16-23`).
    ///
    /// Applied by the shell to whichever tab's `NavigationStack` can reach cycle. `TabBackStacks.push`
    /// puts the *concrete* key into the path, which is what lets this modifier match on `CycleKey`
    /// rather than forcing one central `navigationDestination(for: AnyNavKey.self)` in the app
    /// target (`AnyNavKey.swift:23-29`).
    ///
    /// The two `entry<…>` blocks Kotlin registers become two chained modifiers: SwiftUI matches on
    /// the concrete key type, so each destination is its own line rather than a `when` over a
    /// sealed key.
    public func cycleDestinations() -> some View {
        navigationDestination(for: CycleKey.self) { _ in
            CycleRoute()
        }
        .navigationDestination(for: CycleDayKey.self) { key in
            CycleDayRoute(epochDay: key.epochDay)
        }
    }
}
