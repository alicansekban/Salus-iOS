// Ported from `app/src/main/kotlin/com/alicansekban/salus/navigation/TopLevelBackStack.kt:14-56`,
// with the two structural differences the Kotlin file's own doc comment predicts ("Mirrors
// SwiftUI's NavigationStack(path:) model for the iOS port", `TopLevelBackStack.kt:12`):
//
//  1. **No flattened `backStack`.** Navigation 3 renders one list, so Android keeps a
//     `LinkedHashMap` of per-tab stacks and re-flattens it after every mutation
//     (`TopLevelBackStack.kt:23-28`). SwiftUI renders one `NavigationStack` per tab, each reading
//     its own `NavigationPath`, so the flattening — and with it the map's insertion order, which
//     existed only to order that flat list — has nothing to do here.
//  2. **Tabs are never removed.** Android's `pop()` deletes a tab's stack when it empties and falls
//     back to the previous tab (`TopLevelBackStack.kt:44-53`); that is a consequence of the
//     flattened list, where an empty stack would leave a hole. The five tabs are fixed on both
//     platforms (`ui-rules.md`: "The tab set is fixed"), so here a stack simply sits at its root.
//     The invariant Kotlin's `else` branch protects — the last stack never empties past its root —
//     is what `pop()` below does unconditionally.
//
// Neither difference is a behaviour difference: what the user can do, and what they see when they
// do it, is identical on both platforms.

import Observation
import SwiftUI

/// One `NavigationPath` per top-level tab, so switching tabs preserves the navigation inside each.
///
/// Generic over the tab type rather than hard-wired to the shell's `RootTab`: the app target has no
/// test bundle, so the semantics live here — where they are tested — and the shell keeps only the
/// wiring. `CaseIterable` is what lets the holder seed a path for every tab up front, which makes
/// `path(for:)` total.
@MainActor
@Observable
public final class TabBackStacks<Tab: Hashable & CaseIterable> {
    /// The selected tab — the twin of `TopLevelBackStack.topLevelKey` (`TopLevelBackStack.kt:18`),
    /// `private set` there and here. It moves only through `switchTopLevel(_:)`.
    public private(set) var selection: Tab

    private var paths: [Tab: NavigationPath]

    /// - Parameter initial: the tab shown on launch — Android's `TopLevelBackStack(HomeKey)`
    ///   (`SalusApp.kt:87`).
    ///
    /// Main-actor isolated like the rest of the type — `@Observable`'s generated storage is, so a
    /// `nonisolated init` cannot assign it. A SwiftUI view that builds one in a stored-property
    /// initializer therefore declares itself `@MainActor` (see `App/RootView.swift`).
    public init(initial: Tab) {
        selection = initial
        paths = Dictionary(uniqueKeysWithValues: Tab.allCases.map { ($0, NavigationPath()) })
    }

    /// The path for `tab`, empty when that tab sits at its root.
    public func path(for tab: Tab) -> NavigationPath {
        paths[tab] ?? NavigationPath()
    }

    /// The binding the shell hands `NavigationStack(path:)`.
    ///
    /// SwiftUI writes the whole path back — a swipe-to-go-back is a write, not a call to `pop()` —
    /// so the setter has to land on the tab it was made for and not on whichever tab is selected
    /// when the write arrives.
    public func binding(for tab: Tab) -> Binding<NavigationPath> {
        Binding(
            get: { self.path(for: tab) },
            set: { self.paths[tab] = $0 }
        )
    }

    /// Selects `tab` (`TopLevelBackStack.kt:30-35`).
    ///
    /// Re-selecting the tab that is already selected does nothing, and that is the port, not an
    /// omission: Kotlin's `switchTopLevel` removes the tab's stack from the map and puts the *same*
    /// list straight back, so the stack survives and `topLevelKey` does not move. iOS convention
    /// would pop such a tap to the tab's root; Salus does not, because the two platforms must agree
    /// on what a tab press does.
    ///
    /// A stack left behind by a switch is untouched, which is the whole point of holding one path
    /// per tab.
    public func switchTopLevel(_ tab: Tab) {
        guard tab != selection else { return }
        selection = tab
    }

    /// Pushes `key` onto the selected tab's stack (`TopLevelBackStack.kt:37-40`).
    ///
    /// Through `AnyNavKey.append(to:)`, so what lands in the path is the feature's own key type and
    /// its own `navigationDestination(for:)` matches it. Appending the box instead would leave the
    /// app target as the only place able to resolve a destination.
    public func push(_ key: AnyNavKey) {
        var path = paths[selection] ?? NavigationPath()
        key.append(to: &path)
        paths[selection] = path
    }

    /// Pops the selected tab's stack, stopping at its root (`TopLevelBackStack.kt:42-55`).
    ///
    /// A pop at the root is a no-op rather than an error: on Android the system back gesture takes
    /// this same path (`SalusApp.kt:170`), and the OS is entitled to send one more than there are
    /// entries.
    public func pop() {
        guard var path = paths[selection], !path.isEmpty else { return }
        path.removeLast()
        paths[selection] = path
    }
}
