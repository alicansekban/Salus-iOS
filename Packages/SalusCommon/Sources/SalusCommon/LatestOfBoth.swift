// The twin of `kotlinx.coroutines.flow.combine(a, b) { … }` and of `Flow.map`, for
// `AsyncThrowingStream`.
//
// Neither has a Kotlin counterpart file: Kotlin gets both from the coroutines library, and Swift's
// standard library ships no combine-latest for `AsyncSequence` and no way to map one without
// rebuilding it. `AppointmentsRepositoryImpl` needs the combinator three times
// (`observeUpcoming`, `observePast`, `observeAppointment`), `MedicationsRepositoryImpl` twice, and
// two list/detail ViewModels once each — so it is written once here rather than once per call site,
// and no general-purpose async-algorithms package is added, because that is not on `CLAUDE.md`'s
// closed dependency allowlist.
//
// Both helpers lived as byte-identical copies inside `FeatureAppointments` and `FeatureMedications`
// (and `mapped` inside `FeatureVitals`) until iOS-M6, because features never depend on each other
// and a shared home meant a core-package change. `docs/plans/2026-08-27-ios-m5-medications.md`
// (ruling 8) named the third copy as the moment they move; this is that move. `SalusCommon` is the
// right home rather than `SalusUI`: this is plain Swift concurrency with no UI framework in it.
//
// The `latestOfBoth` semantics are `combine`'s, deliberately narrow:
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
public func latestOfBoth<First: Sendable, Second: Sendable, Value: Sendable>(
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

/// The twin of `Flow.map` over a DAO observation, factored out because two observations over the
/// same DAO would otherwise be the same fifteen lines with one expression changed.
/// `.bufferingNewest(1)` is restated here because `AsyncThrowingStream` is a concrete type rather
/// than a protocol, so mapping means rebuilding the stream and the DAO's conflation has to be
/// restated with it. A failure of the observation finishes the mapped stream with the same error
/// instead of ending it silently — and so does a failure of the mapping itself, which is what a
/// Kotlin `Flow.map` whose lambda throws does (`WeightEntryMapper.kt:16`, `TimeZone.of`).
///
/// `transform` is `throws` so a mapper that can fail fits; a non-throwing mapper is accepted
/// unchanged, which is what `MedicationsRepositoryImpl` passes.
public func mapped<Record: Sendable, Value: Sendable>(
    _ records: AsyncThrowingStream<Record, any Error>,
    _ transform: @escaping @Sendable (Record) throws -> Value
) -> AsyncThrowingStream<Value, any Error> {
    AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
        let task = Task {
            do {
                for try await record in records {
                    try continuation.yield(transform(record))
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        // A consumer that stops reading must stop the observation too.
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
/// change. That interleaving is reachable on the ordinary path, because a write that commits two
/// tables in one transaction (`upsertWithReminders`, `saveWithSchedules`) wakes both observations
/// at once. Serialising `transform` + `yield` makes the emission order the pair order, which is
/// what Kotlin's `combine` guarantees by running both collectors on a single coroutine.
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
