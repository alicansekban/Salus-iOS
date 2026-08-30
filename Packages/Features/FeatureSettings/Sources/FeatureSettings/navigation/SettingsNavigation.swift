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

/// The profile editor, pushed from the More tab's profile row (`SettingsNavigation.kt:17`, drawn
/// by `:42-44`).
///
/// It carries no argument: there is exactly one profile row, seeded by the migration, so the editor
/// has nothing to be told apart by — unlike the vitals and appointment editors, whose keys carry an
/// `entryId`.
public struct ProfileKey: Hashable, Sendable {
    public init() {}
}

/// The About screen, pushed from the More tab's about row (`SettingsNavigation.kt:18`, drawn by
/// `:46-48` on the Kotlin side). The iOS twin of the `@Serializable AboutKey` object — `Hashable` is
/// what `navigationDestination(for:)` requires (see `VitalsNavigation.swift`'s note).
public struct AboutKey: Hashable, Sendable {
    public init() {}
}

extension View {
    /// Registers every destination this feature owns.
    ///
    /// Applied by the shell to the More tab's `NavigationStack`. `TabBackStacks.push` puts the
    /// *concrete* key into the path, which is what lets this modifier match on `ReminderHealthKey`
    /// rather than forcing one central `navigationDestination(for: AnyNavKey.self)` in the app
    /// target (`AnyNavKey.swift:23-29`).
    ///
    /// The three same-feature destinations the More hub pushes — Reminder Health, Profile, About —
    /// are registered here; the cross-feature hops (`onOpenCycle`/`onOpenDoctorReport`/
    /// `onOpenTrends`) are shell callbacks the `MoreRoute` takes, not destinations, because their
    /// keys belong to other features this one cannot see (spec §4).
    public func settingsDestinations() -> some View {
        navigationDestination(for: ReminderHealthKey.self) { _ in
            ReminderHealthRoute()
        }
        .navigationDestination(for: ProfileKey.self) { _ in
            ProfileRoute()
        }
        .navigationDestination(for: AboutKey.self) { _ in
            AboutRoute()
        }
    }
}
