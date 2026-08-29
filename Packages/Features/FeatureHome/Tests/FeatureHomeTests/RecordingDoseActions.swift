// Ported from the `private class RecordingDoseActions : DoseActions` of
// `HomeViewModelTest.kt:63-69`.
//
// Kotlin collects `Triple<String, Int, Int>` into a `MutableList`. Swift tuples are not `Equatable`,
// so an array of them cannot be compared to an expected array in one `#expect`; the recorded call is
// a small `Equatable` struct instead — the same three fields, in the same order, with the names the
// protocol gives them. That is the only difference from the Kotlin.
//
// `@unchecked Sendable` with a lock rather than an actor: `DoseActions` is `Sendable` and the
// recording list is mutable, and the write happens from the detached `Task` `onEvent` launches while
// the assertion reads from the main actor.

import Foundation
import SalusModel

/// A ``DoseActions`` that records instead of writing (`HomeViewModelTest.kt:63-69`).
final class RecordingDoseActions: DoseActions, @unchecked Sendable {
    /// One `markTaken` call — Kotlin's `Triple(scheduleId, epochDay, minuteOfDay)`.
    struct RecordedDose: Equatable, Sendable {
        let scheduleId: String
        let epochDay: Int
        let minuteOfDay: Int
    }

    private let lock = NSLock()
    private var recorded: [RecordedDose] = []

    /// `HomeViewModelTest.kt:64` — every call so far, in order.
    var taken: [RecordedDose] {
        lock.withLock { recorded }
    }

    func markTaken(scheduleId: String, epochDay: Int, minuteOfDay: Int) async throws {
        lock.withLock {
            recorded.append(RecordedDose(scheduleId: scheduleId, epochDay: epochDay, minuteOfDay: minuteOfDay))
        }
    }
}
