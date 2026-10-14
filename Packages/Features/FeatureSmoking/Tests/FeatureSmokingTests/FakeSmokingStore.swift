// Ported from `feature/smoking/src/test/kotlin/com/alicansekban/salus/feature/smoking/
// FakeSmokingStore.kt`.
//
// An in-memory ``SmokingStore``, so a ViewModel test runs the real use cases against it and reads
// back what they wrote. Like the GRDB store, a block that throws leaves nothing behind.
//
// Two additions the Kotlin fake does not have: ``failure`` makes every `mutate` throw before the
// block runs (a storage fault, which no domain rule can produce), and the gate is a small class
// rather than a `CompletableDeferred` because Swift has no such type in the standard library.

import Foundation
import SalusSmoking

/// Holds `mutate` calls until ``open()`` — a write that is still in flight.
final class WriteGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if isOpen {
                lock.unlock()
                continuation.resume()
            } else {
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }

    func open() {
        lock.lock()
        isOpen = true
        let released = waiters
        waiters.removeAll()
        lock.unlock()
        for waiter in released {
            waiter.resume()
        }
    }
}

struct FakeStorageFault: Error, Equatable {}

final class FakeSmokingStore: SmokingStore, @unchecked Sendable {
    static let empty = SmokingInput(plan: nil, prices: [], attempts: [], events: [], goal: nil)

    private let lock = NSLock()
    private var currentInput: SmokingInput
    private var startedCalls = 0
    private var committedCalls = 0
    private var currentGate: WriteGate?
    private var currentFailure: (any Error)?
    private var subscribers: [UUID: AsyncStream<SmokingInput>.Continuation] = [:]

    init(initial: SmokingInput = FakeSmokingStore.empty) {
        currentInput = initial
    }

    /// When set, every `mutate` waits for it before running its block.
    var gate: WriteGate? {
        get { lock.withLock { currentGate } }
        set { lock.withLock { currentGate = newValue } }
    }

    /// When set, every `mutate` throws it before the block runs.
    var failure: (any Error)? {
        get { lock.withLock { currentFailure } }
        set { lock.withLock { currentFailure = newValue } }
    }

    /// How many `mutate` blocks were started, committed or not.
    var calls: Int {
        lock.withLock { startedCalls }
    }

    /// How many `mutate` blocks committed a write; a refused action leaves it at 0.
    var commits: Int {
        lock.withLock { committedCalls }
    }

    var input: SmokingInput {
        lock.withLock { currentInput }
    }

    /// The rows now and after every committed write — Android's `inputFlow`, which a fake
    /// repository folds into snapshots. Keeps only the newest row set, as a `StateFlow` does.
    func inputStream() -> AsyncStream<SmokingInput> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.withLock {
                subscribers[id] = continuation
                continuation.yield(currentInput)
            }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { _ = self?.subscribers.removeValue(forKey: id) }
            }
        }
    }

    func mutate<T: Sendable>(_ block: @escaping @Sendable (any SmokingWrites) throws -> T) async throws -> T {
        let (gate, failure, snapshot) = lock.withLock {
            startedCalls += 1
            return (currentGate, currentFailure, currentInput)
        }
        await gate?.wait()
        if let failure {
            throw failure
        }
        let writes = FakeWrites(input: snapshot)
        let value = try block(writes)
        if writes.wrote {
            lock.withLock {
                currentInput = writes.input
                committedCalls += 1
                for subscriber in subscribers.values {
                    subscriber.yield(writes.input)
                }
            }
        }
        return value
    }
}

private final class FakeWrites: SmokingWrites {
    private(set) var input: SmokingInput
    private(set) var wrote = false

    init(input: SmokingInput) {
        self.input = input
    }

    private func change(_ transform: (SmokingInput) -> SmokingInput) {
        wrote = true
        input = transform(input)
    }

    func savePlan(_ plan: SmokingPlan) throws {
        change { SmokingInput(plan: plan, prices: $0.prices, attempts: $0.attempts, events: $0.events, goal: $0.goal) }
    }

    func addPricePeriod(_ period: PricePeriod) throws {
        change { SmokingInput(
            plan: $0.plan,
            prices: $0.prices + [period],
            attempts: $0.attempts,
            events: $0.events,
            goal: $0.goal
        )
        }
    }

    func updatePricePeriod(_ period: PricePeriod) throws {
        change {
            SmokingInput(
                plan: $0.plan,
                prices: $0.prices.map { $0.id == period.id ? period : $0 },
                attempts: $0.attempts,
                events: $0.events,
                goal: $0.goal
            )
        }
    }

    func addAttempt(_ attempt: QuitAttempt) throws {
        change { SmokingInput(
            plan: $0.plan,
            prices: $0.prices,
            attempts: $0.attempts + [attempt],
            events: $0.events,
            goal: $0.goal
        )
        }
    }

    func updateAttempt(_ attempt: QuitAttempt) throws {
        change {
            SmokingInput(
                plan: $0.plan,
                prices: $0.prices,
                attempts: $0.attempts.map { $0.id == attempt.id ? attempt : $0 },
                events: $0.events,
                goal: $0.goal
            )
        }
    }

    func addEvent(_ event: SmokingEvent) throws {
        change { SmokingInput(
            plan: $0.plan,
            prices: $0.prices,
            attempts: $0.attempts,
            events: $0.events + [event],
            goal: $0.goal
        )
        }
    }

    func updateEvent(_ event: SmokingEvent) throws {
        change {
            SmokingInput(
                plan: $0.plan,
                prices: $0.prices,
                attempts: $0.attempts,
                events: $0.events.map { $0.id == event.id ? event : $0 },
                goal: $0.goal
            )
        }
    }

    func deleteEvent(id: String) throws {
        change {
            SmokingInput(
                plan: $0.plan,
                prices: $0.prices,
                attempts: $0.attempts,
                events: $0.events.filter { $0.id != id },
                goal: $0.goal
            )
        }
    }

    func deleteZeroMarker(epochDay: Int64) throws {
        change {
            SmokingInput(
                plan: $0.plan,
                prices: $0.prices,
                attempts: $0.attempts,
                events: $0.events.filter { !($0.epochDay == epochDay && $0.units == 0) },
                goal: $0.goal
            )
        }
    }

    func saveGoal(_ goal: SavingsGoal) throws {
        change { SmokingInput(plan: $0.plan, prices: $0.prices, attempts: $0.attempts, events: $0.events, goal: goal) }
    }

    func resetAll() throws {
        change { _ in FakeSmokingStore.empty }
    }
}
