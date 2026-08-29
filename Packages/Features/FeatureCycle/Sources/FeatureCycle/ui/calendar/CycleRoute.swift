// The calendar screen's Route, as a placeholder.
//
// iOS-M6 Task 10 builds `CycleScreen.kt`'s twin and replaces this body with the real Route — module
// from the environment, `CycleViewModel` in `@State`, `onOpenDay` pushing `CycleDayKey`. It exists
// now, empty, because `cycleDestinations()` names it (`CycleNavigation.kt:18`) and a navigation
// table that does not compile is not a navigation table.

import SwiftUI

/// The cycle calendar (`CycleScreen.kt:69-83`).
public struct CycleRoute: View {
    public init() {}

    public var body: some View {
        // Task 10 replaces this body.
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
