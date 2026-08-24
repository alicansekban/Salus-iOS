// The two constants Kotlin keeps in `ReminderWindowSynchronizer`'s companion object
// (`ReminderWindowSynchronizer.kt:92-94`), lifted into an injected value.
//
// They are injected rather than hard-coded for the reason spec §6.1 gives: iOS caps *pending
// notification requests* at 64 per app, which Android has no equivalent of, so the two platforms
// ship different numbers on purpose. Injecting them is what lets the ported Kotlin cases run
// against Android's 48h/30 and prove the algorithm, while the app runs the iOS window.

import Foundation

/// How far ahead the engine materializes, and how many occurrences it will hold at once.
public struct ReminderWindowConfig: Sendable {
    /// How far past `now` the rolling window reaches.
    public let window: TimeInterval

    /// The hard ceiling on materialized occurrences, applied earliest-first.
    public let maxOccurrences: Int

    public init(window: TimeInterval, maxOccurrences: Int) {
        self.window = window
        self.maxOccurrences = maxOccurrences
    }

    /// What the app ships (spec §6.1): a 7-day horizon capped at 60 of the 64 pending slots iOS
    /// allows, leaving four for anything scheduled outside the engine.
    public static let ios = Self(window: 7 * 24 * 60 * 60, maxOccurrences: 60)

    /// Android's own constants, so the ported Kotlin cases test the algorithm rather than the
    /// numbers (`ReminderWindowSynchronizer.kt:92-93`).
    public static let androidParity = Self(window: 48 * 60 * 60, maxOccurrences: 30)
}
