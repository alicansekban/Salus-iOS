// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// navigation/VitalsNavigation.kt`.
//
// `EntryProviderScope<NavKey>.vitalsEntries(onOpenTrends:)` builds the feature's `NavEntry`s inside
// the shell's one `NavDisplay`; the iOS twin is a `View` modifier that registers the feature's
// `navigationDestination(for:)` on the shell's `NavigationStack`. Both keep every key inside the
// feature that owns it: the shell names none of them, it just applies the modifier.
//
// `@Serializable` has no twin. Navigation 3 serialises keys to survive process death; a
// `NavigationPath` only serialises when its entries were appended through the `Codable`-constrained
// overload, and nothing in this tree restores a path yet (`AnyNavKey.swift`'s note). `Hashable`
// is what `NavigationPath` and `navigationDestination(for:)` actually require.

import SwiftUI

/// The vitals tab's root (`VitalsNavigation.kt:12-13`).
///
/// Nothing pushes it: `RootTab.vitals` is the iOS shell's tab identity and `VitalsRoute` is the
/// stack's root view, so this key has no `navigationDestination`. It exists because the tab is a
/// destination on Android and a deep link would have to name it here too.
public struct VitalsKey: Hashable, Sendable {
    public init() {}
}

/// The weight editor, new (`entryId == nil`) or editing (`VitalsNavigation.kt:15-16`).
public struct WeightEditorKey: Hashable, Sendable {
    public let entryId: String?

    public init(entryId: String?) {
        self.entryId = entryId
    }
}

// TODO(M7): `BloodPressureEditorKey` and `GlucoseEditorKey` (`VitalsNavigation.kt:18-22`), plus
// their `navigationDestination` registrations below.

extension View {
    /// Registers every destination this feature owns (`VitalsNavigation.kt:29-43`).
    ///
    /// Applied by the shell to the vitals tab's `NavigationStack`. `TabBackStacks.push` puts the
    /// *concrete* key into the path, which is what lets this modifier match on `WeightEditorKey`
    /// rather than forcing one central `navigationDestination(for: AnyNavKey.self)` in the app
    /// target (`AnyNavKey.swift:23-29`).
    ///
    /// `onOpenTrends` is not a parameter here, where Kotlin's `vitalsEntries` takes one: the trends
    /// callback belongs to `VitalsRoute`, which the shell places as the tab's root itself, so it is
    /// passed there instead of threaded through this modifier.
    public func vitalsDestinations() -> some View {
        navigationDestination(for: WeightEditorKey.self) { key in
            WeightEditorRoute(entryId: key.entryId)
        }
    }
}
