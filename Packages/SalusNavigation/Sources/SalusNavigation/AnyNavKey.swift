// The iOS stand-in for Navigation 3's `NavKey` marker interface
// (`core/navigation/src/main/kotlin/com/alicansekban/salus/core/navigation/Navigator.kt:3`).
//
// Android has a nominal type to name: `androidx.navigation3.runtime.NavKey` is an empty interface
// every feature's key conforms to, so `NavCommand.Navigate(val key: NavKey)` can carry any of them
// without the navigation module seeing a single one. SwiftUI has no such marker — `NavigationPath`
// takes any `Hashable` — so the same job needs a type-erasing box instead of a protocol. That is
// what this is, and it is the only place in the port where a Kotlin interface becomes a struct.

import SwiftUI

/// A navigation key, erased to a single type the shell can carry.
///
/// The erasure keeps the property that makes feature isolation compile-time on Android: this
/// module never names a key, so no feature has to be visible to it, and cross-feature navigation
/// stays impossible by construction (`architecture-rules.md`: "NavKeys stay in the feature that
/// owns them").
///
/// Equality and hashing go through `AnyHashable`, which compares the *dynamic type* before the
/// value. Two features that both spell a case `root` therefore stay distinct keys — the alternative
/// would let one feature's destination answer to another's path entry.
///
/// What travels into a `NavigationPath` is the **concrete** key, never this box: the append is
/// captured at construction, while the static type is still known, and replayed by `append(to:)`.
/// That is what lets a feature package own its destinations the way Android's `vitalsEntries` does
/// — it registers `navigationDestination(for: ItsOwnKey.self)` inside its own `…Destinations()`
/// modifier, and the shell never names a key. Erasing all the way into the path would instead force
/// one central `navigationDestination(for: AnyNavKey.self)` in the app target, which is exactly the
/// coupling the erasure exists to prevent.
public struct AnyNavKey: Hashable, Sendable {
    /// The wrapped key, for a call site that knows the type it put in.
    public let base: any Hashable & Sendable

    /// The append, closed over the key at its concrete static type. Not part of equality or
    /// hashing: two boxes are equal when their keys are, and a closure has no identity worth
    /// comparing — `==` and `hash(into:)` below stay written by hand for that reason.
    private let appendToPath: @Sendable (inout NavigationPath) -> Void

    /// Erases `base`. Wrapping an `AnyNavKey` again yields the same key rather than a second box,
    /// so `navigate(_:)` behaves the same whether a feature hands over its own key or an erased one
    /// — and the re-wrapped box carries the *original* append, so the concrete key still lands in
    /// the path.
    public init(_ base: some Hashable & Sendable) {
        if let key = base as? AnyNavKey {
            self = key
        } else {
            self.base = base
            appendToPath = { path in path.append(base) }
        }
    }

    /// Appends the wrapped key to `path` at the type it was constructed with.
    ///
    /// `NavigationPath.append` is generic over `Hashable`, so calling it with `base` — whose static
    /// type here is `any Hashable & Sendable` — would store the existential and match no typed
    /// destination. Replaying the captured closure stores the concrete value instead.
    public func append(to path: inout NavigationPath) {
        appendToPath(&path)
    }

    public static func == (lhs: AnyNavKey, rhs: AnyNavKey) -> Bool {
        AnyHashable(lhs.base) == AnyHashable(rhs.base)
    }

    public func hash(into hasher: inout Hasher) {
        AnyHashable(base).hash(into: &hasher)
    }
}
