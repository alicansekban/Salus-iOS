// Covers `data/LatestOfBoth.swift`, the combinator that stands in for
// `kotlinx.coroutines.flow.combine`. There is no Android twin and there cannot be one: Kotlin's
// `combine` is library code with its own tests, and this file exists because Swift ships no
// equivalent.
//
// The ordering case below is a regression test. The first version of the combinator formed the pair
// under a lock but ran `transform` and `yield` outside it, so a child task descheduled inside
// `transform` could emit its now-stale pair *after* the other child emitted a fresher one — and a
// `bufferingNewest(1)` consumer keeps whatever was written last. `upsertWithReminders` commits the
// appointment and its reminder rows in one transaction, which wakes both observations at once, so
// the interleaving was reachable on the ordinary save path rather than only in theory.

import Foundation
import Testing

@testable import FeatureAppointments

@Suite("latestOfBoth")
struct LatestOfBothTests {
    /// How long the deliberately slow `transform` blocks for, and how long the test waits for both
    /// sides to drain afterwards. `Thread.sleep` rather than `Task.sleep` on purpose: `transform` is
    /// synchronous, and blocking the child task inside it is exactly the deschedule the ordering
    /// guarantee has to survive.
    private static let transformBlock: TimeInterval = 0.03
    private static let settle: UInt64 = 120_000_000

    /// Nothing reaches the consumer until both sides have produced a value — `combine`'s rule, and
    /// what keeps a half-loaded list off the screen.
    @Test("nothing is emitted until both sides have a value")
    func nothingIsEmittedUntilBothSidesHaveAValue() async throws {
        let first = AsyncThrowingStream<Int, any Error>.makeStream()
        let second = AsyncThrowingStream<Int, any Error>.makeStream()
        let combined = latestOfBoth(first.stream, second.stream) { "\($0)-\($1)" }

        // The second side never produces a value, so the two the first side produces pair with
        // nothing and the combined stream finishes without ever emitting.
        first.continuation.yield(1)
        first.continuation.yield(2)
        first.continuation.finish()
        second.continuation.finish()

        var emitted: [String] = []
        for try await value in combined {
            emitted.append(value)
        }
        #expect(emitted.isEmpty)
    }

    /// The regression. A pair formed first must reach the consumer first, however slow the
    /// `transform` that turns it into a value — otherwise the settled value is the superseded one.
    /// Ten rounds, because an ordering property that passes once has only been lucky once.
    @Test("a slow transform never overwrites a fresher pair")
    func aSlowTransformNeverOverwritesAFresherPair() async throws {
        for _ in 0 ..< 10 {
            let first = AsyncThrowingStream<Int, any Error>.makeStream()
            let second = AsyncThrowingStream<Int, any Error>.makeStream()
            let combined = latestOfBoth(first.stream, second.stream) { firstValue, secondValue in
                // The deschedule hook: the pair that must not be last takes long enough for the
                // other child task to form and emit the fresher one.
                if firstValue == 2, secondValue == 1 {
                    Thread.sleep(forTimeInterval: Self.transformBlock)
                }
                return "\(firstValue)-\(secondValue)"
            }

            first.continuation.yield(1)
            second.continuation.yield(1)
            try await Task.sleep(nanoseconds: 10_000_000)
            first.continuation.yield(2) // forms (2, 1) and blocks inside `transform`
            try await Task.sleep(nanoseconds: 5_000_000)
            second.continuation.yield(2) // forms (2, 2) — must not overtake (2, 1)
            try await Task.sleep(nanoseconds: Self.settle)
            first.continuation.finish()
            second.continuation.finish()

            // `bufferingNewest(1)` keeps exactly what was written last, which is the value a
            // consumer would still be showing.
            var settled: String?
            for try await value in combined {
                settled = value
            }
            #expect(settled == "2-2")
        }
    }

    /// A failure on either side fails the combined stream rather than ending it quietly, which is
    /// how a mapper failure reaches the screen instead of blanking it.
    @Test("a failure on either side fails the combined stream")
    func aFailureOnEitherSideFailsTheCombinedStream() async throws {
        let first = AsyncThrowingStream<Int, any Error>.makeStream()
        let second = AsyncThrowingStream<Int, any Error>.makeStream()
        let combined = latestOfBoth(first.stream, second.stream) { "\($0)-\($1)" }

        first.continuation.yield(1)
        second.continuation.finish(throwing: IllegalTimeZoneError.unknownTimeZone("Mars/Olympus_Mons"))
        first.continuation.finish()

        await #expect(throws: IllegalTimeZoneError.unknownTimeZone("Mars/Olympus_Mons")) {
            for try await _ in combined {}
        }
    }
}
