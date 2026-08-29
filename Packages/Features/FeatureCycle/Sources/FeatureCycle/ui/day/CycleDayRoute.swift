// The day-log screen's Route, as a placeholder.
//
// iOS-M6 Task 11 builds `CycleDayScreen.kt`'s twin and replaces this body with the real Route —
// module from the environment, `CycleDayViewModel(epochDay:)` in `@State`. It exists now, empty,
// because `cycleDestinations()` names it (`CycleNavigation.kt:21`) and a navigation table that does
// not compile is not a navigation table.

import SwiftUI

/// One day's log (`CycleDayScreen.kt`).
public struct CycleDayRoute: View {
    /// The day being logged, as the epoch day the key carries.
    let epochDay: Int

    public init(epochDay: Int) {
        self.epochDay = epochDay
    }

    public var body: some View {
        // Task 11 replaces this body.
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
