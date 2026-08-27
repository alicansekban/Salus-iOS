// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// navigation/MedicationsNavigation.kt`.
//
// `EntryProviderScope<NavKey>.medicationsEntries()` builds the feature's `NavEntry`s inside the
// shell's one `NavDisplay`; the iOS twin is a `View` modifier that registers the feature's
// `navigationDestination(for:)` on the shell's `NavigationStack`. Both keep every key inside the
// feature that owns it: the shell names none of them, it just applies the modifier.
//
// `@Serializable` has no twin. Navigation 3 serialises keys to survive process death; a
// `NavigationPath` only serialises when its entries were appended through the `Codable`-constrained
// overload, and nothing in this tree restores a path yet (`AnyNavKey.swift`'s note). `Hashable`
// is what `NavigationPath` and `navigationDestination(for:)` actually require.
//
// `SalusTransitions.push` (`MedicationsNavigation.kt:24, 27`) has no twin either: a
// `NavigationStack` push already animates that way, where Navigation 3 has to be told.
//
// **The two payload keys are spelled `id`, not `medicationId`.** M4 settled it for appointments
// (`AppointmentDetailKey.id`): the type already says what the id belongs to, and repeating the noun
// reads as `MedicationDetailKey(medicationId:)` at every call site. The Kotlin property name is the
// only thing that differs.

import SwiftUI

/// The medications tab's root (`MedicationsNavigation.kt:11-12`).
///
/// Nothing pushes it: `RootTab.medications` is the iOS shell's tab identity and `MedicationsRoute`
/// is the stack's root view, so this key has no `navigationDestination`. It exists because the tab
/// is a destination on Android and a deep link would have to name it here too — a tapped dose alarm
/// is exactly that.
public struct MedicationsKey: Hashable, Sendable {
    public init() {}
}

/// One medication's detail screen (`MedicationsNavigation.kt:14-15`).
public struct MedicationDetailKey: Hashable, Sendable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

/// The editor, new (`id == nil`) or editing (`MedicationsNavigation.kt:17-18`).
public struct MedicationEditorKey: Hashable, Sendable {
    public let id: String?

    public init(id: String?) {
        self.id = id
    }
}

extension View {
    /// Registers every destination this feature owns (`MedicationsNavigation.kt:20-30`).
    ///
    /// Applied by the shell to the medications tab's `NavigationStack`. `TabBackStacks.push` puts
    /// the *concrete* key into the path, which is what lets this modifier match on
    /// `MedicationDetailKey` rather than forcing one central
    /// `navigationDestination(for: AnyNavKey.self)` in the app target (`AnyNavKey.swift:23-29`).
    ///
    /// The two `entry<…>` blocks Kotlin registers become two chained modifiers: SwiftUI matches on
    /// the concrete key type, so each destination is its own line rather than a `when` over a
    /// sealed key.
    public func medicationsDestinations() -> some View {
        navigationDestination(for: MedicationDetailKey.self) { key in
            MedicationDetailPlaceholder(id: key.id)
        }
        .navigationDestination(for: MedicationEditorKey.self) { key in
            MedicationEditorPlaceholder(id: key.id)
        }
    }
}

// MARK: - Placeholders

// The two destinations below stand in for `MedicationDetailRoute` (iOS-M5 **Task 11**) and
// `MedicationEditorRoute` (iOS-M5 **Task 12**), which are the tasks that delete them. They are here
// rather than absent on purpose: an unregistered `navigationDestination` is a push that lands on a
// blank screen with no way back, and the failure would only show up in the app, after Task 13 wires
// the tab. A placeholder that names its key makes a premature push obvious instead.

/// Replaced by `MedicationDetailRoute` in iOS-M5 Task 11.
private struct MedicationDetailPlaceholder: View {
    let id: String

    var body: some View {
        Text(verbatim: "MedicationDetailKey(id: \(id))")
    }
}

/// Replaced by `MedicationEditorRoute` in iOS-M5 Task 12.
private struct MedicationEditorPlaceholder: View {
    let id: String?

    var body: some View {
        Text(verbatim: "MedicationEditorKey(id: \(id ?? "nil"))")
    }
}
