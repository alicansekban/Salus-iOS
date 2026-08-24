// The twin of `kotlinx.coroutines.flow.combine(a, b) { … }` for two `AsyncThrowingStream`s.
//
// It has no Kotlin counterpart file: Kotlin gets `combine` from the coroutines library, and Swift's
// standard library ships no combine-latest for `AsyncSequence`. `AppointmentsRepositoryImpl` needs
// one three times (`observeUpcoming`, `observePast`, `observeAppointment`), so it is written once
// here rather than three times there — and nowhere else, because a general-purpose async-algorithms
// package is not on `CLAUDE.md`'s closed dependency allowlist.
//
// The semantics are `combine`'s, deliberately narrow:
//  - nothing is emitted until **both** sides have produced a value;
//  - after that every value from either side emits, paired with the other's latest;
//  - the first failure on either side fails the combined stream, as `combine` cancels its siblings
//    and rethrows;
//  - the combined stream finishes when both sides have finished. Database observations do not
//    finish on their own, so in practice the consumer's cancellation is what ends it.

import Foundation

/// Emits `transform(latestFirst, latestSecond)` whenever either side produces a value and both
/// have produced at least one.
func latestOfBoth<First: Sendable, Second: Sendable, Value: Sendable>(
    _ first: AsyncThrowingStream<First, any Error>,
    _ second: AsyncThrowingStream<Second, any Error>,
    _ transform: @escaping @Sendable (First, Second) throws -> Value
) -> AsyncThrowingStream<Value, any Error> {
    // `bufferingNewest(1)` is the conflation `SalusDatabase`'s DAOs already apply to each side, so
    // a slow consumer is handed the current pair, never a queue of superseded ones.
    AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
        let latest = LatestPair<First, Second>()
        let task = Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for try await value in first {
                            if let pair = latest.setFirst(value) {
                                try continuation.yield(transform(pair.first, pair.second))
                            }
                        }
                    }
                    group.addTask {
                        for try await value in second {
                            if let pair = latest.setSecond(value) {
                                try continuation.yield(transform(pair.first, pair.second))
                            }
                        }
                    }
                    // Rethrows the first child failure, which cancels the other child — `combine`'s
                    // behaviour, and the reason a mapper failure reaches the screen.
                    try await group.waitForAll()
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        // A consumer that stops reading must stop both observations too.
        continuation.onTermination = { _ in task.cancel() }
    }
}

/// The latest value seen on each side. `@unchecked Sendable` for `FixedSalusClock`'s reason: the
/// two slots are mutable state shared by two child tasks, and the lock is what makes the promise
/// true. Both setters answer with the pair to emit, so reading and updating stay one critical
/// section — otherwise two values arriving together could emit the same pair twice and skip one.
private final class LatestPair<First: Sendable, Second: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var first: First?
    private var second: Second?

    func setFirst(_ value: First) -> (first: First, second: Second)? {
        lock.withLock {
            first = value
            guard let second else { return nil }
            return (value, second)
        }
    }

    func setSecond(_ value: Second) -> (first: First, second: Second)? {
        lock.withLock {
            second = value
            guard let first else { return nil }
            return (first, value)
        }
    }
}
