// The twin of Android's `feature/settings/src/test/kotlin/.../data/FreeOnlyPremiumStatusTest.kt`,
// which has no Kotlin counterpart — the type is iOS-only (recorded divergence (d)). The shape is
// the `FreeOnlyPremiumStatus` test the Home package would carry if it had one: the value is
// pinned, and the stream's non-termination is pinned.
//
// The non-termination check is the load-bearing one: `FreeOnlyMorePremiumStatus` emits `.free` and
// never finishes, because the Kotlin source is a `StateFlow`, which never completes either
// (`FreeOnlyPremiumStatus.swift:18-24` carries the full reasoning). A stream that ended after its
// single value would be a second difference from the type iOS-M9 replaces it with. The check uses a
// bounded timeout race: if the stream *did* finish, a second `next()` would return `nil` in
// microseconds, so the bound turns a regression into a recorded failure instead of a hung test.

import Foundation
import Testing

@testable import FeatureSettings

@Suite("FreeOnlyMorePremiumStatus")
struct MorePremiumStandInTests {
    @Test("the first emission is .free")
    func firstEmissionIsFree() async {
        let status = FreeOnlyMorePremiumStatus()

        var iterator = status.status.makeAsyncIterator()
        let first = await iterator.next()

        #expect(first == .free)
    }

    @Test("the stream never finishes: a second next() does not return nil")
    func streamNeverFinishes() async {
        let status = FreeOnlyMorePremiumStatus()

        // A finished stream's `next()` returns `nil` immediately. A live one suspends. The timeout
        // is the only honest way to prove a negative — short enough that a regression (a
        // `continuation.finish()` added later) fails in a fraction of a second rather than hanging
        // the suite.
        //
        // `AsyncStream.makeAsyncIterator()`'s iterator is not `Sendable`, so it cannot be captured
        // into the `sending` closure a `TaskGroup` child task requires, and the second `next()`
        // must run on the same iterator the first one drained. A standalone `Task` that owns the
        // iterator end-to-end is the only shape that works: it pulls the first value, then pulls
        // the second, and hands the second to a one-shot gate that races a timeout. The gate is an
        // actor, so the two racing tasks resume it through serialised access; only the first
        // resume wins.
        let gate = OneShotGate()
        let streamTask = Task {
            var iterator = status.status.makeAsyncIterator()
            _ = await iterator.next() // drain the single emitted `.free`
            let second = await iterator.next() // never returns for a live stream
            await gate.resume(with: second)
        }
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200 ms
            await gate.resume(with: nil)
        }
        let second = await gate.value()

        // Cancel whichever task is still parked so it does not outlive the test.
        streamTask.cancel()
        timeoutTask.cancel()

        // A `nil` here means the timeout won the race — the stream did not finish, which is what
        // the test asserts. A non-`nil` means the stream returned a second value or finished, both
        // of which are regressions.
        #expect(second == nil, "the stream finished or emitted a second value; it must stay open")
    }
}

/// A one-shot race gate: the first of two racing tasks to call `resume(with:)` wins, and the loser
/// is a no-op. The actor's serialised access is what makes the double-resume safe.
private actor OneShotGate {
    private var value: MorePremiumStatusValue?
    private var resumed = false
    private var waiter: CheckedContinuation<MorePremiumStatusValue?, Never>?

    /// Resumes the waiter with `value` on the first call only; later calls are no-ops.
    func resume(with value: MorePremiumStatusValue?) {
        guard !resumed else { return }
        resumed = true
        self.value = value
        waiter?.resume(returning: value)
        waiter = nil
    }

    /// Suspends until `resume(with:)` is called, then returns the winning value.
    func value() async -> MorePremiumStatusValue? {
        if resumed {
            return value
        }
        return await withCheckedContinuation { continuation in
            if resumed {
                continuation.resume(returning: value)
            } else {
                waiter = continuation
            }
        }
    }
}
