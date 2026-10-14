// Twin of `core/smoking/.../data/SmokingRepositoryImpl.kt`.
//
// Android folds one `invalidationTracker` flow over all five tables into a single transactional
// read, because combining five DAO flows would emit a mixed state after a multi-table commit (a
// QUIT plan seen before its new attempt) and the screens route on exactly that. The DAO here has
// five observers and exposes reads only inside `write(_:)`, so the same thing is built from them:
// each observer is only a "something changed" tick, and every tick re-reads all five tables in
// one transaction. A commit that touches several tables yields several ticks but the first read
// after it already sees all of it; the repeats are dropped as equal.

import Foundation
import os
import SalusCommon
import SalusDatabase

final class SmokingRepositoryImpl: SmokingRepository {
    private static let logger = Logger(subsystem: "com.alicansekban.salus", category: "smoking")
    private static let minuteMs: Int64 = 60000

    private let dao: SmokingDao
    private let store: any SmokingStore
    private let clock: any SalusClock
    private let idGenerator: any IdGenerator
    /// The repair runs once per process; the repair itself is idempotent, so a race only repeats a no-op.
    private let repaired = OnceFlag()

    init(dao: SmokingDao, store: any SmokingStore, clock: any SalusClock, idGenerator: any IdGenerator) {
        self.dao = dao
        self.store = store
        self.clock = clock
        self.idGenerator = idGenerator
    }

    func observeInput() -> AsyncStream<SmokingInput> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                await repairOnce()
                var last: SmokingInput?
                for await _ in changeTicks() {
                    guard let input = await readInput() else { break }
                    if input != last {
                        last = input
                        continuation.yield(input)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func observeSnapshot() -> AsyncStream<SmokingSnapshot> {
        // The tick only says "recompute"; the instant is read from the clock at that moment, so a
        // write between two ticks is never calculated against a "now" that predates it.
        let combined = latestOfBoth(
            throwingStream(over: observeInput()),
            throwingStream(over: minuteTicks())
        ) { [self] input, _ in snapshot(of: input) }
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                do {
                    for try await snapshot in combined {
                        continuation.yield(snapshot)
                    }
                } catch {
                    Self.logger.error("smoking snapshot stream failed: \(String(describing: error), privacy: .private)")
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func snapshotNow() async -> SmokingSnapshot {
        await repairOnce()
        guard let input = await readInput() else { return .notSetUp }
        return snapshot(of: input)
    }

    private func snapshot(of input: SmokingInput) -> SmokingSnapshot {
        SmokingStatsCalculator.snapshot(input, nowMs: clock.nowEpochMilliseconds(), zone: clock.timeZone())
    }

    /// One consistent read of the five tables. Nil (after logging) when storage fails.
    private func readInput() async -> SmokingInput? {
        do {
            return try await dao.write { try $0.readInput() }
        } catch {
            Self.logger.error("smoking read failed: \(String(describing: error), privacy: .private)")
            return nil
        }
    }

    /// A tick whenever any of the five tables changes, and once at subscription.
    private func changeTicks() -> AsyncStream<Void> {
        let dao = dao
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await forwardTicks(of: dao.observePlan(), to: continuation) }
                    group.addTask { await forwardTicks(of: dao.observePricePeriods(), to: continuation) }
                    group.addTask { await forwardTicks(of: dao.observeAttempts(), to: continuation) }
                    group.addTask { await forwardTicks(of: dao.observeEvents(), to: continuation) }
                    group.addTask { await forwardTicks(of: dao.observeActiveGoal(), to: continuation) }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Emits at once, then at the top of every minute, so live counters change when the minute does.
    private func minuteTicks() -> AsyncStream<Void> {
        let clock = clock
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                while !Task.isCancelled {
                    continuation.yield(())
                    let delay = Self.minuteMs - clock.nowEpochMilliseconds() % Self.minuteMs
                    do {
                        try await Task.sleep(for: .milliseconds(delay))
                    } catch {
                        break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Contract §6 "repair on load": a QUIT plan with no active attempt gets one opened at the
    /// plan's creation instant, so the counter has something to count from, and §8.10: the entries
    /// logged while it had none are re-derived against it. Checked against the rows inside the
    /// store's transaction, so a second run finds the attempt and does nothing.
    private func repairOnce() async {
        if repaired.isSet {
            return
        }
        let idGenerator = idGenerator
        do {
            let opened: Bool = try await store.mutate { writes in
                let input = writes.input
                guard let plan = input.plan, plan.mode == .quit,
                      !input.attempts.contains(where: { $0.endedAtMs == nil })
                else { return false }
                let attempt = QuitAttempt(
                    id: idGenerator.newId(),
                    startedAtMs: plan.createdAtMs,
                    tzId: plan.tzId,
                    endedAtMs: nil,
                    endReason: nil
                )
                try writes.addAttempt(attempt)
                // The new window may cover entries that were logged while the plan had none.
                for event in changedEvents(
                    from: input.events,
                    to: reattach(input.events, to: input.attempts + [attempt])
                ) {
                    try writes.updateEvent(event)
                }
                return true
            }
            if opened {
                Self.logger.warning("QUIT plan had no active attempt; opened one at the plan's creation instant")
            }
            repaired.set()
        } catch {
            // The screens still render from whatever rows exist; the next observe retries.
            Self.logger.error("smoking repair failed: \(String(describing: error), privacy: .private)")
        }
    }
}

/// Forwards "the table changed" for every element of `source`; a failed observation ends the
/// whole tick stream (the consumer logs nothing more than the end).
private func forwardTicks<Value: Sendable>(
    of source: AsyncThrowingStream<Value, any Error>,
    to continuation: AsyncStream<Void>.Continuation
) async {
    do {
        for try await _ in source {
            continuation.yield(())
        }
    } catch {
        continuation.finish()
    }
}

private final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool {
        lock.withLock { value }
    }

    func set() {
        lock.withLock { value = true }
    }
}
