// No Android twin. Kotlin's tests drive `runTest`'s virtual scheduler with `advanceUntilIdle()`;
// Swift Testing has no such scheduler, so "wait until the state has caught up" is spelled as a poll.
//
// The poll is bounded by a clock deadline, not by a count of yields: a fixed number of main-actor
// yields can be spent before a busy cooperative pool gives the awaited work a turn. The deadline
// turns a broken expectation into a recorded failure instead of a hung test run.
//
// The one copy of `SalusTesting/WaitUntil.swift` left in the tree, kept identical to it on purpose:
// `SalusTesting` depends on `SalusCommon`, so importing it here would be a dependency cycle — the
// same reason `SalusClockTests` writes its own `StubClock` instead of using `FixedSalusClock`.

import Testing

/// Polls on the main actor until `condition` holds, or records a failure after `timeout`.
///
/// - Parameters:
///   - what: named in the failure message, so a timeout says which expectation never came true.
///   - timeout: wall-clock time to spend before giving up. Generous, because a healthy run returns
///     within a few milliseconds and only a broken expectation pays it.
@MainActor
func waitUntil(
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
