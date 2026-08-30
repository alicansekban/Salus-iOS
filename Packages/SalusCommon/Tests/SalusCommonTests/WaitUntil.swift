// No Android twin. Kotlin's tests drive `runTest`'s virtual scheduler with `advanceUntilIdle()`;
// Swift Testing has no such scheduler, so the same "let every task that is already runnable finish"
// step is spelled as a bounded yield loop.
//
// This waits on the cooperative pool, never on wall-clock time: `Task.yield()` hands the main actor
// to whatever is enqueued and comes straight back. The bound turns a broken expectation into a
// recorded failure instead of a hung test run.
//
// Copied from `FeatureSettingsTests/WaitUntil.swift` (iOS-M8): a test helper cannot be shared from
// `SalusTesting`, which depends on `SalusCommon` — importing it here would be a dependency cycle,
// the same reason `SalusClockTests` writes its own `StubClock` instead of using `FixedSalusClock`.

import Testing

/// Yields the main actor until `condition` holds.
///
/// - Parameters:
///   - what: named in the failure message, so a timeout says which expectation never came true.
///   - limit: how many yields to spend before giving up. High enough that no healthy test reaches
///     it (the deepest chain here is two hops), low enough that a hang fails in milliseconds.
@MainActor
func waitUntil(
    _ what: String,
    limit: Int = 1000,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () -> Bool
) async {
    for _ in 0 ..< limit {
        if condition() {
            return
        }
        await Task.yield()
    }
    Issue.record("timed out waiting for \(what)", sourceLocation: sourceLocation)
}
