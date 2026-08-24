// Ported from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/appointments/
// navigation/AppointmentsNavigation.kt`.
//
// `EntryProviderScope<NavKey>.appointmentsEntries()` builds the feature's `NavEntry`s inside the
// shell's one `NavDisplay`; the iOS twin is a `View` modifier that registers the feature's
// `navigationDestination(for:)` on the shell's `NavigationStack`. Both keep every key inside the
// feature that owns it: the shell names none of them, it just applies the modifier.
//
// `@Serializable` has no twin. Navigation 3 serialises keys to survive process death; a
// `NavigationPath` only serialises when its entries were appended through the `Codable`-constrained
// overload, and nothing in this tree restores a path yet (`AnyNavKey.swift`'s note). `Hashable`
// is what `NavigationPath` and `navigationDestination(for:)` actually require.
//
// `SalusTransitions.push` (`AppointmentsNavigation.kt:22, 25`) has no twin either: a
// `NavigationStack` push already animates that way, where Navigation 3 has to be told.

import SwiftUI

/// The appointments tab's root (`AppointmentsNavigation.kt:11-12`).
///
/// Nothing pushes it: `RootTab.appointments` is the iOS shell's tab identity and
/// `AppointmentsRoute` is the stack's root view, so this key has no `navigationDestination`. It
/// exists because the tab is a destination on Android and a deep link would have to name it here
/// too — a tapped appointment reminder is exactly that (global constraints, decision 2).
public struct AppointmentsKey: Hashable, Sendable {
    public init() {}
}

/// One appointment's detail screen (`AppointmentsNavigation.kt:14-15`).
public struct AppointmentDetailKey: Hashable, Sendable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

/// The editor, new (`id == nil`) or editing (`AppointmentsNavigation.kt:17-18`).
public struct AppointmentEditorKey: Hashable, Sendable {
    public let id: String?

    public init(id: String?) {
        self.id = id
    }
}

extension View {
    /// Registers every destination this feature owns (`AppointmentsNavigation.kt:20-30`).
    ///
    /// Applied by the shell to the appointments tab's `NavigationStack`. `TabBackStacks.push` puts
    /// the *concrete* key into the path, which is what lets this modifier match on
    /// `AppointmentDetailKey` rather than forcing one central
    /// `navigationDestination(for: AnyNavKey.self)` in the app target (`AnyNavKey.swift:23-29`).
    ///
    /// **`AppointmentEditorKey` is not registered yet, on purpose.** `AppointmentEditorRoute`
    /// arrives with the editor slice and adds its own `navigationDestination(for:)` line beside
    /// this one. Until then the list and the detail screen still publish that key (the FAB, the
    /// Edit button), the shell still applies this modifier, and an unregistered push is a
    /// no-op rather than a crash — which is what an unfinished feature should look like, instead
    /// of a placeholder screen pretending to be a destination.
    public func appointmentsDestinations() -> some View {
        navigationDestination(for: AppointmentDetailKey.self) { key in
            AppointmentDetailRoute(appointmentId: key.id)
        }
    }
}
