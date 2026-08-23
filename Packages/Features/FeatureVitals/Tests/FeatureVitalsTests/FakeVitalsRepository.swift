// Ported 1:1 from
// `feature/vitals/src/test/kotlin/com/alicansekban/salus/feature/vitals/FakeVitalsRepository.kt`.
//
// Weight only, because `VitalsRepository` is weight only until M7 brings blood pressure and
// glucose over; the Kotlin fake's other two halves are line-for-line the same shape and arrive
// with them.
//
// Kotlin backs the fake with a `MutableStateFlow<Map<String, WeightEntry>>` and derives both
// observations from it with `map`. Swift has no `StateFlow`, so the map is guarded by a lock and
// every live observation is registered as a callback that is fired on each mutation: the same
// "one source of truth, several derived views" behaviour, spelled out. Two differences, neither
// of which any assertion depends on:
//
//  - `StateFlow` drops a value equal to the one it already holds; this re-emits on every
//    mutation, so a test that writes the same entry twice sees two emissions rather than one.
//  - `bufferingNewest(1)` is the conflation `SalusDatabase`'s DAOs use, so a slow consumer here
//    behaves like a slow consumer of the real repository.

import Foundation

@testable import FeatureVitals

/// An in-memory `VitalsRepository` for tests that must not reach a database
/// (`FakeVitalsRepository.kt:14-56`).
///
/// `@unchecked Sendable` for `FixedSalusClock`'s reason: the state is mutable, and the lock is
/// what makes the promise true.
final class FakeVitalsRepository: VitalsRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String: WeightEntry] = [:]
    private var observers: [UUID: @Sendable ([String: WeightEntry]) -> Void] = [:]

    /// `FakeVitalsRepository.kt:20-22`.
    func setEntries(_ items: WeightEntry...) {
        mutate { entries in
            entries = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        }
    }

    /// `FakeVitalsRepository.kt:32`.
    func current() -> [WeightEntry] {
        lock.withLock { Array(entries.values) }
    }

    /// `FakeVitalsRepository.kt:38-43` — the window is closed at both ends, as `BETWEEN` is.
    func observeWeightHistory(from: Date, until: Date) -> AsyncThrowingStream<[WeightEntry], any Error> {
        stream { entries in
            entries.values
                .filter { $0.measuredAt >= from && $0.measuredAt <= until }
                .sorted { $0.measuredAt < $1.measuredAt }
        }
    }

    /// `FakeVitalsRepository.kt:45-46`.
    func observeLatestWeight() -> AsyncThrowingStream<WeightEntry?, any Error> {
        stream { entries in entries.values.max { $0.measuredAt < $1.measuredAt } }
    }

    /// `FakeVitalsRepository.kt:48`.
    func getWeightEntry(id: String) async throws -> WeightEntry? {
        lock.withLock { entries[id] }
    }

    /// `FakeVitalsRepository.kt:50-52`.
    func saveWeightEntry(_ entry: WeightEntry) async throws {
        mutate { entries in entries[entry.id] = entry }
    }

    /// `FakeVitalsRepository.kt:54-56`.
    func deleteWeightEntry(id: String) async throws {
        mutate { entries in entries[id] = nil }
    }

    /// The twin of `MutableStateFlow.map`: a derived view that is re-published whenever the map
    /// behind it changes, and that starts by publishing what the map holds right now.
    private func stream<Value: Sendable>(
        _ derive: @escaping @Sendable ([String: WeightEntry]) -> Value
    ) -> AsyncThrowingStream<Value, any Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let token = UUID()
            lock.withLock {
                observers[token] = { snapshot in continuation.yield(derive(snapshot)) }
                continuation.yield(derive(entries))
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                lock.withLock { _ = observers.removeValue(forKey: token) }
            }
        }
    }

    /// Mutates under the lock and publishes the result to every live observation, which is what
    /// assigning to `MutableStateFlow.value` does in one statement.
    private func mutate(_ change: (inout [String: WeightEntry]) -> Void) {
        lock.withLock {
            change(&entries)
            for publish in observers.values {
                publish(entries)
            }
        }
    }
}
