// No Android twin. Kotlin's ViewModel tests drive `runTest`'s virtual scheduler with
// `advanceUntilIdle()`; Swift Testing has no such scheduler, so the same "let every task that is
// already runnable finish" step is spelled as a bounded yield loop. The same shape
// `FeatureVitalsTests/WaitUntil.swift` uses.

import Testing

/// Yields the main actor until `condition` holds.
///
/// - Parameters:
///   - what: named in the failure message, so a timeout says which expectation never came true.
///   - limit: how many yields to spend before giving up. High enough that no healthy test reaches
///     it, low enough that a hang fails in milliseconds.
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
