// The iOS stand-in for Navigation 3's `NavKey` marker interface
// (`core/navigation/src/main/kotlin/com/alicansekban/salus/core/navigation/Navigator.kt:3`).
//
// Android has a nominal type to name: `androidx.navigation3.runtime.NavKey` is an empty interface
// every feature's key conforms to, so `NavCommand.Navigate(val key: NavKey)` can carry any of them
// without the navigation module seeing a single one. SwiftUI has no such marker — `NavigationPath`
// takes any `Hashable` — so the same job needs a type-erasing box instead of a protocol. That is
// what this is, and it is the only place in the port where a Kotlin interface becomes a struct.

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
public struct AnyNavKey: Hashable, Sendable {
    /// The wrapped key, for a call site that knows the type it put in.
    public let base: any Hashable & Sendable

    /// Erases `base`. Wrapping an `AnyNavKey` again yields the same key rather than a second box,
    /// so `navigate(_:)` behaves the same whether a feature hands over its own key or an erased one.
    public init(_ base: some Hashable & Sendable) {
        if let key = base as? AnyNavKey {
            self = key
        } else {
            self.base = base
        }
    }

    public static func == (lhs: AnyNavKey, rhs: AnyNavKey) -> Bool {
        AnyHashable(lhs.base) == AnyHashable(rhs.base)
    }

    public func hash(into hasher: inout Hasher) {
        AnyHashable(base).hash(into: &hasher)
    }
}
