// Ported 1:1 from `feature/medications/src/test/kotlin/com/alicansekban/salus/feature/
// medications/Fakes.kt`.
//
// Kotlin backs the fake with two `MutableStateFlow`s — `medications` and `logs` — and derives
// every observation from them with `map`. Swift has no `StateFlow`, so both lists live in one
// lock-guarded `State` and every live observation is a callback fired on each mutation: the same
// "one source of truth, several derived views" behaviour, spelled out. This is
// `FakeAppointmentsRepository`'s shape, with its two documented differences — this re-emits on
// every mutation where `StateFlow` would drop a value equal to the one it holds, and
// `bufferingNewest(1)` matches the conflation the real DAOs apply.
//
// One difference is this fake's own: Kotlin's two flows are independent, so writing a log never
// wakes a medication observation. Here the two share a publisher, which means a derived view can
// re-emit an unchanged value after an unrelated write. Collectors in this package are conflated
// and compare what they receive, so an extra identical emission is not observable — and keeping
// one state means the fake cannot publish a half-applied mutation.

import Foundation
import SalusModel
import SalusReminder

@testable import FeatureMedications

/// One recorded ``FeatureMedications/MedicationRepository/decrementStock(medicationId:amount:)``
/// call — Kotlin's `Pair<String, Double>` (`Fakes.kt:23`).
struct StockDecrement: Equatable, Sendable {
    let medicationId: String
    let amount: Double
}

/// One recorded ``FeatureMedications/MedicationRepository/setRemindersEnabled(medicationId:enabled:)``
/// call — Kotlin's `Pair<String, Boolean>` (`Fakes.kt:67`).
struct ReminderToggle: Equatable, Sendable {
    let medicationId: String
    let enabled: Bool
}

/// An in-memory `MedicationRepository` for tests that must not reach a database
/// (`Fakes.kt:19-83`).
///
/// `@unchecked Sendable` for `FixedSalusClock`'s reason: the state is mutable, and the lock is
/// what makes the promise true.
final class FakeMedicationRepository: MedicationRepository, @unchecked Sendable {
    private struct State {
        var medications: [MedicationWithSchedules] = []
        var logs: [IntakeLog] = []
    }

    private let lock = NSLock()
    private var state = State()
    private var stockDecrementCalls: [StockDecrement] = []
    private var reminderToggleCalls: [ReminderToggle] = []
    private var observers: [UUID: @Sendable (State) -> Void] = [:]

    init() {}

    /// The twin of assigning to `medications.value` (`Fakes.kt:21`).
    func setMedications(_ items: [MedicationWithSchedules]) {
        mutate { state in state.medications = items }
    }

    /// The twin of reading `medications.value`.
    var medications: [MedicationWithSchedules] {
        lock.withLock { state.medications }
    }

    /// The twin of reading `logs.value`.
    var logs: [IntakeLog] {
        lock.withLock { state.logs }
    }

    /// `Fakes.kt:23` — every `decrementStock` call, in order.
    var stockDecrements: [StockDecrement] {
        lock.withLock { stockDecrementCalls }
    }

    /// `Fakes.kt:67` — every `setRemindersEnabled` call, in order.
    var reminderToggles: [ReminderToggle] {
        lock.withLock { reminderToggleCalls }
    }

    /// `Fakes.kt:25-26`.
    func observeActiveMedications() -> AsyncThrowingStream<[MedicationWithSchedules], any Error> {
        stream { state in state.medications.filter(\.medication.isActive) }
    }

    /// `Fakes.kt:28-29`.
    func getMedication(id: String) async throws -> MedicationWithSchedules? {
        lock.withLock { state.medications.first { $0.medication.id == id } }
    }

    /// `Fakes.kt:31-32`.
    func observeMedication(id: String) -> AsyncThrowingStream<MedicationWithSchedules?, any Error> {
        stream { state in state.medications.first { $0.medication.id == id } }
    }

    /// `Fakes.kt:34-37` — the inactive schedules are dropped, exactly as the real repository
    /// deactivates rather than stores them.
    func saveMedication(_ medication: Medication, schedules: [MedicationSchedule]) async throws {
        mutate { state in
            state.medications = state.medications.filter { $0.medication.id != medication.id }
                + [MedicationWithSchedules(medication: medication, schedules: schedules.filter(\.isActive))]
        }
    }

    /// `Fakes.kt:39-41`.
    func deleteMedication(id: String) async throws {
        mutate { state in state.medications = state.medications.filter { $0.medication.id != id } }
    }

    /// `Fakes.kt:43-44`.
    func getAllActiveMedications() async throws -> [MedicationWithSchedules] {
        lock.withLock { state.medications.filter(\.medication.isActive) }
    }

    /// `Fakes.kt:46-47`.
    func getSchedule(scheduleId: String) async throws -> MedicationSchedule? {
        lock.withLock { state.medications.flatMap(\.schedules).first { $0.id == scheduleId } }
    }

    /// `Fakes.kt:49-52`.
    func getLog(scheduleId: String, epochDay: Int, minuteOfDay: Int) async throws -> IntakeLog? {
        lock.withLock {
            state.logs.first {
                $0.scheduleId == scheduleId && $0.epochDay == epochDay && $0.minuteOfDay == minuteOfDay
            }
        }
    }

    /// `Fakes.kt:54-59` — keyed by the (schedule, day, minutes) triple, never by id.
    func upsertLog(_ log: IntakeLog) async throws {
        mutate { state in
            state.logs = state.logs.filter {
                !($0.scheduleId == log.scheduleId && $0.epochDay == log.epochDay
                    && $0.minuteOfDay == log.minuteOfDay)
            } + [log]
        }
    }

    /// `Fakes.kt:61-62`. Kotlin's `it.epochDay in from..to` is spelled as two comparisons: a
    /// Swift `ClosedRange` traps when its bounds are inverted, where Kotlin's range is simply
    /// empty, and a fake that crashes on a reversed window would hide the caller's bug.
    func observeLogsBetween(
        fromEpochDay: Int,
        toEpochDay: Int
    ) -> AsyncThrowingStream<[IntakeLog], any Error> {
        stream { state in state.logs.filter { $0.epochDay >= fromEpochDay && $0.epochDay <= toEpochDay } }
    }

    /// `Fakes.kt:64-65`.
    func getLogsBetween(fromEpochDay: Int, toEpochDay: Int) async throws -> [IntakeLog] {
        lock.withLock { state.logs.filter { $0.epochDay >= fromEpochDay && $0.epochDay <= toEpochDay } }
    }

    /// `Fakes.kt:69-78`.
    func setRemindersEnabled(medicationId: String, enabled: Bool) async throws {
        mutate { state in
            reminderToggleCalls.append(ReminderToggle(medicationId: medicationId, enabled: enabled))
            state.medications = state.medications.map { entry in
                guard entry.medication.id == medicationId else { return entry }
                return MedicationWithSchedules(
                    medication: entry.medication.with(remindersEnabled: enabled),
                    schedules: entry.schedules
                )
            }
        }
    }

    /// `Fakes.kt:80-82`.
    func decrementStock(medicationId: String, amount: Double) async throws {
        lock.withLock {
            stockDecrementCalls.append(StockDecrement(medicationId: medicationId, amount: amount))
        }
    }

    /// The twin of `MutableStateFlow.map`: a derived view re-published whenever the state behind it
    /// changes, starting with what the state holds right now.
    private func stream<Value: Sendable>(
        _ derive: @escaping @Sendable (State) -> Value
    ) -> AsyncThrowingStream<Value, any Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let token = UUID()
            lock.withLock {
                observers[token] = { snapshot in continuation.yield(derive(snapshot)) }
                continuation.yield(derive(state))
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                lock.withLock { _ = observers.removeValue(forKey: token) }
            }
        }
    }

    /// Mutates under the lock and publishes the result to every live observation, which is what
    /// assigning to `MutableStateFlow.value` does in one statement.
    private func mutate(_ change: (inout State) -> Void) {
        lock.withLock {
            change(&state)
            for publish in observers.values {
                publish(state)
            }
        }
    }
}

/// Counts `requestSync()` calls (`Fakes.kt:85-92`).
///
/// A class rather than a struct, because a use case holds it as `any ReminderScheduler` and the
/// count has to be readable through that reference after the call.
final class FakeReminderScheduler: ReminderScheduler, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    init() {}

    /// `Fakes.kt:86-87`.
    var syncRequests: Int {
        lock.withLock { count }
    }

    /// `Fakes.kt:89-91`.
    func requestSync() {
        lock.withLock { count += 1 }
    }
}

extension Medication {
    /// The twin of Kotlin's `data class` `copy(remindersEnabled = enabled)` (`Fakes.kt:73`).
    /// Swift has no synthesised `copy`, and a memberwise call at the call site would bury the one
    /// field that changes under eleven that do not.
    fileprivate func with(remindersEnabled: Bool) -> Medication {
        Medication(
            id: id,
            name: name,
            form: form,
            strengthValue: strengthValue,
            strengthUnit: strengthUnit,
            instructions: instructions,
            stockCount: stockCount,
            stockThreshold: stockThreshold,
            startDateEpochDay: startDateEpochDay,
            endDateEpochDay: endDateEpochDay,
            isActive: isActive,
            remindersEnabled: remindersEnabled
        )
    }
}
