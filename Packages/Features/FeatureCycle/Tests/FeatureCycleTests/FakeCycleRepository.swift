// Ported 1:1 from `feature/cycle/src/test/kotlin/com/alicansekban/salus/feature/cycle/
// FakeCycleRepository.kt`.
//
// Kotlin backs the fake with three `MutableStateFlow`s — `periods`, `dayLogs` and `symptoms` — and
// derives every observation from them with `map`. Swift has no `StateFlow`, so all three live in
// one lock-guarded `State` and every live observation is a callback fired on each mutation: the
// same "one source of truth, several derived views" behaviour, spelled out. This is
// `FakeMedicationRepository`'s shape, with its documented differences — this re-emits on every
// mutation where `StateFlow` would drop a value equal to the one it holds, and
// `bufferingNewest(1)` matches the conflation the real DAOs apply — and with one correction.
//
// The correction: `FakeMedicationRepository.mutate` publishes to its continuations *while holding
// the lock* (`FakeMedicationRepository.swift:194-201`, and `FakeAppointmentsRepository.swift:123`
// before it). That is a latent deadlock — a continuation's `onTermination` runs on whatever thread
// drops the last reference, and it takes the same lock — and it holds the lock for the duration of
// arbitrary collector code. Here the mutation and the publishing are two steps: the lock is taken
// to apply the change and copy out the observers, then released, and only then is the new snapshot
// yielded. `stream(_:)` registers the same way — the observer goes into the table and the current
// state is copied out under the lock, and the seed value is yielded after the lock is dropped.
//
// **The residual window is a stale last value, not a duplicate.** A mutation that lands between
// the registration and the seed's yield reaches the new observer first, so the collector's buffer
// receives the fresh snapshot and then the seed — and `bufferingNewest(1)` keeps the *last* one
// written, which is the stale seed. The collector then sits on a value one mutation old until the
// next write. Nothing in this package can hit it (every test registers its observation before it
// mutates, and `waitUntil` polls rather than trusting one delivery), and closing it properly means
// serializing every yield per subscriber behind a second lock — more machinery than a fake that no
// test can trip should carry. Named here so the next reader does not have to re-derive it.
//
// Kotlin's three flows are independent, so writing a day log never wakes a period observation.
// Here the three share a publisher, which means a derived view can re-emit an unchanged value
// after an unrelated write — same trade as the medications fake, and keeping one state means the
// fake cannot publish a half-applied mutation.

import Foundation
import SalusModel

@testable import FeatureCycle

/// An in-memory `CycleRepository` for tests that must not reach a database
/// (`FakeCycleRepository.kt:12-59`).
///
/// `@unchecked Sendable` for `FakeMedicationRepository`'s reason: the state is mutable, and the
/// lock is what makes the promise true.
final class FakeCycleRepository: CycleRepository, @unchecked Sendable {
    private struct State {
        var periods: [String: CyclePeriod] = [:]
        var dayLogs: [LocalDate: CycleDayLog] = [:]
        var symptoms: [Symptom] = FakeCycleRepository.defaultCatalog
    }

    private let lock = NSLock()
    private var state = State()
    private var observers: [UUID: @Sendable (State) -> Void] = [:]

    init() {}

    /// The twin of assigning to `periods.value` (`FakeCycleRepository.kt:18-20`).
    func setPeriods(_ items: CyclePeriod...) {
        mutate { state in
            state.periods = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        }
    }

    /// The twin of assigning to `symptoms.value` (`FakeCycleRepository.kt:22-24`).
    func setSymptoms(_ items: [Symptom]) {
        mutate { state in state.symptoms = items }
    }

    /// `FakeCycleRepository.kt:26` — ascending by start date, which is the opposite of what
    /// ``observePeriods()`` emits, so a test that reads state and a screen that collects it are
    /// asserting different orders on purpose.
    func currentPeriods() -> [CyclePeriod] {
        lock.withLock { state.periods.values.sorted { $0.startDate < $1.startDate } }
    }

    /// `FakeCycleRepository.kt:28`.
    func currentDayLogs() -> [CycleDayLog] {
        lock.withLock { state.dayLogs.values.sorted { $0.date < $1.date } }
    }

    /// `FakeCycleRepository.kt:30-31` — descending by start date, newest period first.
    func observePeriods() -> AsyncThrowingStream<[CyclePeriod], any Error> {
        stream { state in state.periods.values.sorted { $0.startDate > $1.startDate } }
    }

    /// `FakeCycleRepository.kt:33-34` — the open period with the latest start, so a stale open
    /// record cannot shadow the one the user is actually in.
    func getOpenPeriod() async throws -> CyclePeriod? {
        lock.withLock { state.periods.values.filter(\.isOpen).max { $0.startDate < $1.startDate } }
    }

    /// `FakeCycleRepository.kt:36-37`.
    func getPeriodStartingOn(_ date: LocalDate) async throws -> CyclePeriod? {
        lock.withLock { state.periods.values.first { $0.startDate == date } }
    }

    /// `FakeCycleRepository.kt:39-41` — keyed by id, so saving an ended copy replaces the open one.
    func savePeriod(_ period: CyclePeriod) async throws {
        mutate { state in state.periods[period.id] = period }
    }

    /// `FakeCycleRepository.kt:43-45`.
    func deletePeriod(id: String) async throws {
        mutate { state in state.periods.removeValue(forKey: id) }
    }

    /// `FakeCycleRepository.kt:47` — the catalog is emitted as it stands; unlike the real
    /// repository, the fake never seeds it on first collection.
    func observeSymptoms() -> AsyncThrowingStream<[Symptom], any Error> {
        stream { state in state.symptoms }
    }

    /// `FakeCycleRepository.kt:49`.
    func getDayLog(on date: LocalDate) async throws -> CycleDayLog? {
        lock.withLock { state.dayLogs[date] }
    }

    /// `FakeCycleRepository.kt:51-53` — keyed by day, never by id: one log per date.
    func saveDayLog(_ log: CycleDayLog) async throws {
        mutate { state in state.dayLogs[log.date] = log }
    }

    /// `FakeCycleRepository.kt:55-59` — the starter catalog every fake begins with.
    static let defaultCatalog: [Symptom] = [
        Symptom(id: "symptom-cramps", nameKey: "cramps", isCustom: false, iconToken: nil),
        Symptom(id: "symptom-headache", nameKey: "headache", isCustom: false, iconToken: nil),
        Symptom(id: "symptom-fatigue", nameKey: "fatigue", isCustom: false, iconToken: nil)
    ]

    /// The twin of `MutableStateFlow.map`: a derived view re-published whenever the state behind it
    /// changes, starting with what the state holds right now.
    private func stream<Value: Sendable>(
        _ derive: @escaping @Sendable (State) -> Value
    ) -> AsyncThrowingStream<Value, any Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let token = UUID()
            let snapshot = lock.withLock {
                observers[token] = { snapshot in continuation.yield(derive(snapshot)) }
                return state
            }
            // Outside the lock, like every other publish in this file.
            continuation.yield(derive(snapshot))
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                lock.withLock { _ = observers.removeValue(forKey: token) }
            }
        }
    }

    /// Mutates under the lock, then publishes the result to every live observation **after
    /// releasing it** — which is what assigning to `MutableStateFlow.value` does in one statement,
    /// minus the deadlock a collector could otherwise reach back into.
    private func mutate(_ change: (inout State) -> Void) {
        let (snapshot, publishers) = lock.withLock { () -> (State, [@Sendable (State) -> Void]) in
            change(&state)
            return (state, Array(observers.values))
        }
        for publish in publishers {
            publish(snapshot)
        }
    }
}
