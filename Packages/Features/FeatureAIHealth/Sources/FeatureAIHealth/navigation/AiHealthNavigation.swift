// Ported from `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/
// navigation/AiHealthNavigation.kt`.
//
// `EntryProviderScope<NavKey>.aiHealthEntries()` builds the feature's `NavEntry`s inside the
// shell's one `NavDisplay`; the iOS twin is a `View` modifier that registers the feature's
// `navigationDestination(for:)` on the shell's `NavigationStack`. Both keep every key inside the
// feature that owns it: the shell names none of them, it just applies the modifier.
//
// `@Serializable` has no twin. Navigation 3 serialises keys to survive process death; a
// `NavigationPath` only serialises when its entries were appended through the `Codable`-constrained
// overload, and nothing in this tree restores a path yet (`AnyNavKey.swift`'s note). `Hashable`
// is what `NavigationPath` and `navigationDestination(for:)` actually require.
//
// `SalusTransitions.push` (`AiHealthNavigation.kt:17`) has no twin either: a `NavigationStack`
// push already animates that way, where Navigation 3 has to be told.
//
// The doctor-report key is absent, and that is the milestone split: `DoctorReportKey` belongs to
// Task 6 of iOS-M10, which ships the report screen. This file registers only what this task's
// summary screen owns.

import SwiftUI

/// The AI health summary, pushed on top of whichever tab the user opened it from — Home today
/// (`AiHealthNavigation.kt:10-11`).
///
/// It is not a tab root, so it carries the push transition and the shell hides the bottom bar
/// for it automatically.
public struct AiSummaryKey: Hashable, Sendable {
    public init() {}
}

extension View {
    /// Registers every destination this feature owns (`AiHealthNavigation.kt:16-23`).
    ///
    /// Applied by the shell to whichever tab's `NavigationStack` can reach the AI summary. The
    /// `entry<AiSummaryKey>` block Kotlin registers becomes one chained modifier: SwiftUI matches
    /// on the concrete key type, so each destination is its own line rather than a `when` over a
    /// sealed key.
    public func aiHealthDestinations() -> some View {
        navigationDestination(for: AiSummaryKey.self) { _ in
            AiSummaryRoute()
        }
    }
}
