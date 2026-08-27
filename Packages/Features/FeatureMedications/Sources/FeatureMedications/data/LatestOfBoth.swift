// The twin of `kotlinx.coroutines.flow.combine(a, b) { … }` for two `AsyncThrowingStream`s.
//
// It has no Kotlin counterpart file: Kotlin gets `combine` from the coroutines library, and Swift's
// standard library ships no combine-latest for `AsyncSequence`. `MedicationsRepositoryImpl` needs
// one twice (`observeActiveMedications`, `observeMedication`), so it is written once here rather
// than twice there — and no third time in this package, because a general-purpose
// async-algorithms package is not on `CLAUDE.md`'s closed dependency allowlist.
//
// **The same combinator as `FeatureAppointments/data/LatestOfBoth.swift`, on purpose** — the code
// is byte-for-byte identical; only this header and one doc reference below (`saveWithSchedules`
// where appointments names `upsertWithReminders`, the write that wakes both observations at once
// in each feature) differ. A feature package cannot import another feature package
// ("features never depend on each other"), and a shared home for it would be a `SalusCommon`
// change rather than a feature one; the template sanctions the duplicate, the way
// `WaitUntil.swift` is already duplicated per feature. Ruling recorded: if a third feature needs
// it, that is the moment it moves.
//
// The semantics are `combine`'s, deliberately narrow:
//  - nothing is emitted until **both** sides have produced a value;
//  - after that every value from either side emits, paired with the other's latest;
//  - the first failure on either side fails the combined stream, as `combine` cancels its siblings
//    and rethrows;
//  - the combined stream finishes when both sides have finished. Database observations do not
//    finish on their own, so in practice the consumer's cancellation is what ends it;
//  - and it is **ordered**: pairs reach the consumer in the order they were formed. That is the
//    property `combine` gets for free from running its collectors on one coroutine and the reason
//    `LatestPair` runs `transform` and `yield` inside its lock — see the note on the class.

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
                            try latest.setFirst(value) { first, second in
                                try continuation.yield(transform(first, second))
                            }
                        }
                    }
                    group.addTask {
                        for try await value in second {
                            try latest.setSecond(value) { first, second in
                                try continuation.yield(transform(first, second))
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
/// true.
///
/// The setters take the emission as a closure and run it **while still holding the lock**, rather
/// than answering with a pair for the caller to emit afterwards. Forming the pair atomically is not
/// enough: with the emission outside the lock, one child can form `(new, old)`, be descheduled
/// inside `transform`, let the other child form and emit `(new, new)`, and then emit its stale pair
/// last — which a `bufferingNewest(1)` consumer keeps as its current value until the next database
/// change. That interleaving is reachable on the ordinary path, because `saveWithSchedules`
/// commits both tables in one transaction and so wakes both observations at once. Serialising
/// `transform` + `yield` makes the emission order the pair order, which is what Kotlin's `combine`
/// guarantees by running both collectors on a single coroutine.
///
/// Holding a lock across the two calls is safe here because neither re-enters this class:
/// `transform` is a pure mapping (record → domain) and `yield` on a `bufferingNewest(1)`
/// continuation stores the value and, at most, resumes a consumer that is suspended elsewhere.
private final class LatestPair<First: Sendable, Second: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var first: First?
    private var second: Second?

    func setFirst(_ value: First, emit: (First, Second) throws -> Void) rethrows {
        try lock.withLock {
            first = value
            guard let second else { return }
            try emit(value, second)
        }
    }

    func setSecond(_ value: Second, emit: (First, Second) throws -> Void) rethrows {
        try lock.withLock {
            second = value
            guard let first else { return }
            try emit(first, value)
        }
    }
}
