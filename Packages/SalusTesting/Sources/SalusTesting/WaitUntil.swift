// No Android twin. Kotlin's ViewModel tests drive `runTest`'s virtual scheduler with
// `advanceUntilIdle()`; Swift Testing has no such scheduler, so "wait until the ViewModel has caught
// up" is spelled as a poll on the `@Observable` state.
//
// The poll is bounded by a clock deadline, not by a count of yields. A ViewModel's work runs on
// cooperative-pool threads; a fixed number of main-actor yields can be spent in microseconds before
// a busy pool gives such a thread a turn, so a healthy run timed out under load. A one-millisecond
// sleep between checks hands the pool real time, and the deadline turns a broken expectation into a
// recorded failure instead of a hung test run.
//
// It lives here rather than in each feature's test target because a test target cannot import
// another package's test target, and features never depend on each other; every feature test
// target already depends on `SalusTesting`.

import Testing

/// Polls on the main actor until `condition` holds, or records a failure after `timeout`.
///
/// - Parameters:
///   - what: named in the failure message, so a timeout says which expectation never came true.
///   - timeout: wall-clock time to spend before giving up. Generous, because a healthy run returns
///     within a few milliseconds and only a broken expectation pays it.
@MainActor
public func waitUntil(
    _ what: String,
    timeout: Duration = .seconds(5),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () -> Bool
) async {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() {
            return
        }
        try? await Task.sleep(for: .milliseconds(1))
    }
    if !condition() {
        Issue.record("timed out waiting for \(what)", sourceLocation: sourceLocation)
    }
}
