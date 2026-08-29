// Covers `ThrowingStream.swift`'s adapter. There is no Android twin and there cannot be one:
// Kotlin has a single `Flow` type whose collector may throw, so nothing needs adapting. The
// adapter exists only because Swift splits the two into unrelated concrete types.
//
// Two cases, the two halves of "it adds no behaviour, only the error type": every value arrives, in
// order, and the source's end ends the wrapper — and the cancellation that a consumer's `break` or
// a cancelled collecting task performs travels back to the source, so a screen that goes away does
// not leave an observation running.

import Foundation
import Testing

@testable import SalusCommon

@Suite("throwingStream(over:)")
struct ThrowingStreamTests {
    /// How long the cancellation case waits for the cancellation to reach the source. Generous on
    /// purpose: what is asserted is that it arrives at all, not how fast.
    private static let cancellationDeadline: TimeInterval = 2

    /// The consumer is given a moment to actually start reading, so the cancellation lands on a
    /// forwarder that is suspended on the source rather than on one that has not started.
    private static let consumerStart: UInt64 = 20_000_000

    @Test("values are forwarded in order and the source's end finishes the wrapper")
    func valuesAreForwardedInOrderAndTheSourcesEndFinishesTheWrapper() async throws {
        let source = AsyncStream<Int>.makeStream()
        let wrapped = throwingStream(over: source.stream)
        var iterator = wrapped.makeAsyncIterator()

        // One value at a time: `.bufferingNewest(1)` keeps only the newest, so a burst yielded
        // before the consumer reads would legitimately collapse to its last element.
        for value in 1 ... 3 {
            source.continuation.yield(value)
            let forwarded = try await iterator.next()
            #expect(forwarded == value)
        }

        source.continuation.finish()
        let afterEnd = try await iterator.next()
        #expect(afterEnd == nil)
    }

    @Test("cancelling the consumer cancels the forwarder")
    func cancellingTheConsumerCancelsTheForwarder() async throws {
        let source = AsyncStream<Int>.makeStream()
        let sourceEnded = TerminationFlag()
        source.continuation.onTermination = { _ in sourceEnded.set() }
        let wrapped = throwingStream(over: source.stream)

        let consumer = Task {
            for try await _ in wrapped {}
        }
        source.continuation.yield(1)
        try await Task.sleep(nanoseconds: Self.consumerStart)
        consumer.cancel()

        let reached = await sourceEnded.becameSet(within: Self.cancellationDeadline)
        #expect(reached)
    }
}

/// The one bit a cancellation case observes, in a box both the termination handler and the test can
/// touch. `@unchecked Sendable` for `LatestPair`'s reason: the lock is what makes the promise true.
///
/// Not `private`: `LatestOfAllTests` watches five of these at once for the same cancellation
/// property, and a second copy of eighteen lines would be the thing this file exists to avoid.
final class TerminationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var isSet = false

    func set() {
        lock.withLock { isSet = true }
    }

    /// Polls rather than awaits a signal, so an adapter that never cancels its source fails the
    /// case instead of hanging the suite.
    func becameSet(within deadline: TimeInterval) async -> Bool {
        let expiry = Date().addingTimeInterval(deadline)
        while Date() < expiry {
            if lock.withLock({ isSet }) {
                return true
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        return lock.withLock { isSet }
    }
}
