// The adapter that lets a non-throwing `AsyncStream` join the throwing combinators in
// `LatestOfBoth.swift` and `LatestOfAll.swift`.
//
// No Kotlin counterpart file, and there cannot be one: Kotlin has a single `Flow` type whose
// collector may throw, so a settings flow and a database flow are already the same type. Swift
// splits them into two unrelated concrete types, so an observation that cannot fail has to be
// re-typed before it can be combined with one that can.
//
// It lived as a `private static` inside `FeatureCycle`'s `CycleViewModel` from iOS-M6, which
// recorded the hoist as owed "when a second feature needs it"
// (`docs/plans/2026-08-29-ios-m6-cycle.md`, Task 9 deferrals); iOS-M7's home dashboard is that
// second feature. The body below is the one that was there — only the access level changed.

/// Re-types a non-throwing `AsyncStream` as the throwing one `latestOfBoth` combines.
///
/// Nothing else changes: every value is forwarded, the end of the source finishes the wrapper,
/// and a consumer that stops reading cancels the source. `.bufferingNewest(1)` restates the
/// conflation the source already applies, because `AsyncThrowingStream` is a concrete type and
/// wrapping means rebuilding.
public func throwingStream<Value: Sendable>(
    over source: AsyncStream<Value>
) -> AsyncThrowingStream<Value, any Error> {
    AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
        let task = Task {
            for await value in source {
                continuation.yield(value)
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
