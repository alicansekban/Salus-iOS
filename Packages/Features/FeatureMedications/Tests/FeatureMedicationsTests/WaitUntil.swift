// No Android twin. Kotlin's ViewModel tests drive `runTest`'s virtual scheduler with
// `advanceUntilIdle()`; Swift Testing has no such scheduler, so the same "let every task that is
// already runnable finish" step is spelled as a bounded yield loop.
//
// This waits on the cooperative pool, never on wall-clock time: `Task.yield()` hands the main actor
// to whatever is enqueued and comes straight back. The bound turns a broken expectation into a
// recorded failure instead of a hung test run.
//
// **Byte-for-byte the same helper as `FeatureAppointmentsTests/WaitUntil.swift`, on purpose.** A test
// target cannot import another package's test target, and the feature template's "features never
// depend on each other" rule makes a shared home for it a `SalusTesting` change rather than a
// feature one. The template sanctions the duplicate: every feature that tests an `@Observable`
// ViewModel carries this file.

import Testing

/// Yields the main actor until `condition` holds.
///
/// - Parameters:
///   - what: named in the failure message, so a timeout says which expectation never came true.
///   - limit: how many yields to spend before giving up. High enough that no healthy test reaches
///     it (the deepest chain here is three hops), low enough that a hang fails in milliseconds.
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
