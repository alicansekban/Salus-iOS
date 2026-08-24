// Ported from `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/
// navigation/SettingsNavigation.kt`.
//
// `EntryProviderScope<NavKey>.settingsEntries()` becomes a `View` modifier the shell applies to the
// More tab's `NavigationStack`, exactly as `vitalsDestinations()` does for its tab. Both keep every
// key inside the feature that owns it: the shell names none of them.
//
// `@Serializable` has no twin — see `VitalsNavigation.swift`'s note. `Hashable` is what
// `NavigationPath` and `navigationDestination(for:)` actually require.

import SwiftUI

/// Reminder Health, pushed from the More tab.
public struct ReminderHealthKey: Hashable, Sendable {
    public init() {}
}

// TODO(M8): the settings hub itself, plus the keys its rows push. Until it lands the More tab's
// root is the shell's placeholder, which carries the one row this milestone needs.

extension View {
    /// Registers every destination this feature owns.
    ///
    /// Applied by the shell to the More tab's `NavigationStack`. `TabBackStacks.push` puts the
    /// *concrete* key into the path, which is what lets this modifier match on `ReminderHealthKey`
    /// rather than forcing one central `navigationDestination(for: AnyNavKey.self)` in the app
    /// target (`AnyNavKey.swift:23-29`).
    public func settingsDestinations() -> some View {
        navigationDestination(for: ReminderHealthKey.self) { _ in
            ReminderHealthRoute()
        }
    }
}
