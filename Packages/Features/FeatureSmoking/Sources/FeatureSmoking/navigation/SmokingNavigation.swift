// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/navigation/
// SmokingNavigation.kt`.
//
// `EntryProviderScope<NavKey>.smokingEntries(…)` becomes a `View` modifier registering the
// feature's `navigationDestination(for:)`s on the shell's `NavigationStack`; every key stays
// inside the feature, the shell names none. The keys are `Hashable`, not `Codable` — see
// `CycleNavigation.swift` for why `@Serializable` has no twin.
//
// Every smoking screen is pushed, so the tab bar is hidden under all of them by the shell
// (`RootView.tabStack(for:)`); nothing here touches it.

import SwiftUI

/// The four-step setup wizard; replaced by ``SmokingKey`` once the plan is written.
public struct SmokingSetupKey: Hashable, Sendable {
    public init() {}
}

/// The main screen: the entry point once a plan exists.
public struct SmokingKey: Hashable, Sendable {
    public init() {}
}

/// The craving flow; `source` says which screen opened it ("main", "home", "notification").
public struct SmokingCravingKey: Hashable, Sendable {
    public let source: String

    public init(source: String = "main") {
        self.source = source
    }
}

/// The health timeline, optionally scrolled to and highlighting one stage.
public struct SmokingTimelineKey: Hashable, Sendable {
    public let highlightStageId: String?

    public init(highlightStageId: String? = nil) {
        self.highlightStageId = highlightStageId
    }
}

public struct SmokingHistoryKey: Hashable, Sendable {
    public init() {}
}

public struct SmokingSettingsKey: Hashable, Sendable {
    public init() {}
}

extension View {
    /// Registers every destination this feature owns.
    ///
    /// `onOpenTrends` and `onOpenReminderHealth` are the cross-feature callbacks: Trends and the
    /// reminder-readiness screen belong to other features, whose keys this one cannot see, so the
    /// shell fills them in. The main screen opens Trends; the settings screen will use the other.
    /// Only the keys that already have a screen are registered — each later task adds its own
    /// `navigationDestination` beside the screen it builds.
    public func smokingDestinations(
        onOpenTrends: @escaping () -> Void,
        onOpenReminderHealth: @escaping () -> Void
    ) -> some View {
        navigationDestination(for: SmokingSetupKey.self) { _ in
            SmokingSetupRoute()
        }
        .navigationDestination(for: SmokingKey.self) { _ in
            SmokingMainRoute(onOpenTrends: onOpenTrends)
        }
    }
}
