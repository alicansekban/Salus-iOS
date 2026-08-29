// Ported 1:1 from
// `feature/vitals/src/test/kotlin/com/alicansekban/salus/feature/vitals/FakeVitalsRepository.kt`.
//
// Kotlin backs the fake with three `MutableStateFlow<Map<String, T>>` — one per vital type — and
// derives every observation from them with `map`. Swift has no `StateFlow`, so each map is a
// ``FakeVitalsStore``: the entries behind a lock, and every live observation registered as a
// callback fired on each mutation. Three differences from Kotlin, none of which an assertion
// depends on:
//
//  - `StateFlow` drops a value equal to the one it already holds; a store re-emits on every
//    mutation, so a test that writes the same entry twice sees two emissions rather than one.
//  - `bufferingNewest(1)` is the conflation `SalusDatabase`'s DAOs use, so a slow consumer here
//    behaves like a slow consumer of the real repository.
//  - **Kotlin's `Map.values` has no defined order and neither does Swift's `Dictionary`** — the
//    open finding from iOS-M2. A store therefore keeps insertion order beside the map, so
//    `current()`, `currentBloodPressure()` and `currentGlucose()` answer what was put in, in the
//    order it was put in, and a test that reads `.first` is reading a fact rather than a coin
//    flip. The observations sort by `measuredAt` anyway, exactly as Kotlin's do.

import Foundation
import SalusModel

@testable import FeatureVitals

/// An in-memory `VitalsRepository` for tests that must not reach a database
/// (`FakeVitalsRepository.kt:14-92`).
///
/// `@unchecked Sendable` for `FixedSalusClock`'s reason: the state is mutable, and the locks
/// inside the three stores are what make the promise true.
final class FakeVitalsRepository: VitalsRepository, @unchecked Sendable {
    private let weight = FakeVitalsStore<WeightEntry>(id: { $0.id }, measuredAt: { $0.measuredAt })
    private let bloodPressure = FakeVitalsStore<BloodPressureEntry>(
        id: { $0.id },
        measuredAt: { $0.measuredAt }
    )
    private let glucose = FakeVitalsStore<GlucoseEntry>(id: { $0.id }, measuredAt: { $0.measuredAt })

    /// `FakeVitalsRepository.kt:20-22`.
    func setEntries(_ items: WeightEntry...) {
        weight.setAll(items)
    }

    /// `FakeVitalsRepository.kt:24-26`.
    func setBloodPressureEntries(_ items: BloodPressureEntry...) {
        bloodPressure.setAll(items)
    }

    /// `FakeVitalsRepository.kt:28-30`.
    func setGlucoseEntries(_ items: GlucoseEntry...) {
        glucose.setAll(items)
    }

    /// `FakeVitalsRepository.kt:32`.
    func current() -> [WeightEntry] {
        weight.current()
    }

    /// `FakeVitalsRepository.kt:34`.
    func currentBloodPressure() -> [BloodPressureEntry] {
        bloodPressure.current()
    }

    /// `FakeVitalsRepository.kt:36`.
    func currentGlucose() -> [GlucoseEntry] {
        glucose.current()
    }

    // MARK: - Weight (FakeVitalsRepository.kt:38-56)

    /// `FakeVitalsRepository.kt:38-43` — the window is closed at both ends, as `BETWEEN` is.
    func observeWeightHistory(from: Date, until: Date) -> AsyncThrowingStream<[WeightEntry], any Error> {
        weight.observeHistory(from: from, until: until)
    }

    /// `FakeVitalsRepository.kt:45-46`.
    func observeLatestWeight() -> AsyncThrowingStream<WeightEntry?, any Error> {
        weight.observeLatest()
    }

    /// `FakeVitalsRepository.kt:48`.
    func getWeightEntry(id: String) async throws -> WeightEntry? {
        weight.value(id: id)
    }

    /// `FakeVitalsRepository.kt:50-52`.
    func saveWeightEntry(_ entry: WeightEntry) async throws {
        weight.put(entry)
    }

    /// `FakeVitalsRepository.kt:54-56`.
    func deleteWeightEntry(id: String) async throws {
        weight.remove(id: id)
    }

    // MARK: - Blood pressure (FakeVitalsRepository.kt:58-74)

    /// `FakeVitalsRepository.kt:58-63`.
    func observeBloodPressureHistory(
        from: Date,
        until: Date
    ) -> AsyncThrowingStream<[BloodPressureEntry], any Error> {
        bloodPressure.observeHistory(from: from, until: until)
    }

    /// `FakeVitalsRepository.kt:65-66`.
    func getBloodPressureEntry(id: String) async throws -> BloodPressureEntry? {
        bloodPressure.value(id: id)
    }

    /// `FakeVitalsRepository.kt:68-70`.
    func saveBloodPressureEntry(_ entry: BloodPressureEntry) async throws {
        bloodPressure.put(entry)
    }

    /// `FakeVitalsRepository.kt:72-74`.
    func deleteBloodPressureEntry(id: String) async throws {
        bloodPressure.remove(id: id)
    }

    // MARK: - Glucose (FakeVitalsRepository.kt:76-91)

    /// `FakeVitalsRepository.kt:76-81`.
    func observeGlucoseHistory(from: Date, until: Date) -> AsyncThrowingStream<[GlucoseEntry], any Error> {
        glucose.observeHistory(from: from, until: until)
    }

    /// `FakeVitalsRepository.kt:83`.
    func getGlucoseEntry(id: String) async throws -> GlucoseEntry? {
        glucose.value(id: id)
    }

    /// `FakeVitalsRepository.kt:85-87`.
    func saveGlucoseEntry(_ entry: GlucoseEntry) async throws {
        glucose.put(entry)
    }

    /// `FakeVitalsRepository.kt:89-91`.
    func deleteGlucoseEntry(id: String) async throws {
        glucose.remove(id: id)
    }
}

/// One `MutableStateFlow<Map<String, Value>>`, spelled out: the entries in insertion order behind
/// a lock, plus the live observations derived from them.
///
/// Generic because the three halves of `FakeVitalsRepository.kt` are line-for-line the same shape
/// over three entry types, and writing the lock and the observer bookkeeping three times is three
/// chances to get one of them wrong.
final class FakeVitalsStore<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private let id: @Sendable (Value) -> String
    private let measuredAt: @Sendable (Value) -> Date
    /// The ids in the order they were first written — the fix for the iOS-M2 finding that
    /// `Dictionary.values` has no defined order.
    private var order: [String] = []
    private var byId: [String: Value] = [:]
    private var observers: [UUID: @Sendable ([Value]) -> Void] = [:]

    init(
        id: @escaping @Sendable (Value) -> String,
        measuredAt: @escaping @Sendable (Value) -> Date
    ) {
        self.id = id
        self.measuredAt = measuredAt
    }

    /// The twin of `entries.value = items.associateBy { it.id }`: the whole map replaced at once.
    func setAll(_ items: [Value]) {
        mutate {
            order = []
            byId = [:]
            for item in items {
                insert(item)
            }
        }
    }

    /// The twin of `entries.value.values.toList()`, in insertion order.
    func current() -> [Value] {
        lock.withLock { snapshot() }
    }

    /// The twin of `entries.value[id]`.
    func value(id: String) -> Value? {
        lock.withLock { byId[id] }
    }

    /// The twin of `entries.value + (entry.id to entry)`: an id already present keeps its place.
    func put(_ item: Value) {
        mutate { insert(item) }
    }

    /// The twin of `entries.value - id`.
    func remove(id: String) {
        mutate {
            byId[id] = nil
            order.removeAll { $0 == id }
        }
    }

    /// The window is closed at both ends, as the DAO's `BETWEEN` is, and oldest first.
    func observeHistory(from: Date, until: Date) -> AsyncThrowingStream<[Value], any Error> {
        let measuredAt = measuredAt
        return stream { items in
            items
                .filter { measuredAt($0) >= from && measuredAt($0) <= until }
                .sorted { measuredAt($0) < measuredAt($1) }
        }
    }

    /// The twin of `maxByOrNull { it.measuredAt }`.
    func observeLatest() -> AsyncThrowingStream<Value?, any Error> {
        let measuredAt = measuredAt
        return stream { items in items.max { measuredAt($0) < measuredAt($1) } }
    }

    /// The twin of `MutableStateFlow.map`: a derived view that is re-published whenever the store
    /// behind it changes, and that starts by publishing what the store holds right now.
    private func stream<Out: Sendable>(
        _ derive: @escaping @Sendable ([Value]) -> Out
    ) -> AsyncThrowingStream<Out, any Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let token = UUID()
            let items = lock.withLock {
                observers[token] = { items in continuation.yield(derive(items)) }
                return snapshot()
            }
            // Outside the lock: publishing under it would let a collector's `onTermination` reach
            // back in — `FakeCycleReminderSettings`' correction.
            continuation.yield(derive(items))
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                lock.withLock { _ = observers.removeValue(forKey: token) }
            }
        }
    }

    /// Mutates under the lock and publishes the result to every live observation afterwards, which
    /// is what assigning to `MutableStateFlow.value` does in one statement.
    private func mutate(_ change: () -> Void) {
        let (items, publishers) = lock.withLock { () -> ([Value], [@Sendable ([Value]) -> Void]) in
            change()
            return (snapshot(), Array(observers.values))
        }
        for publish in publishers {
            publish(items)
        }
    }

    /// Callers hold the lock.
    private func insert(_ item: Value) {
        let key = id(item)
        if byId[key] == nil {
            order.append(key)
        }
        byId[key] = item
    }

    /// Callers hold the lock.
    private func snapshot() -> [Value] {
        order.compactMap { byId[$0] }
    }
}
