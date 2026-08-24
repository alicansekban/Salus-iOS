// Ported 1:1 from `feature/appointments/src/test/kotlin/com/alicansekban/salus/feature/
// appointments/FakeAppointmentsRepository.kt`.
//
// Kotlin backs the fake with a `MutableStateFlow<Map<String, Appointment>>` and derives every
// observation from it with `map`. Swift has no `StateFlow`, so the map is guarded by a lock and
// every live observation is registered as a callback fired on each mutation: the same "one source
// of truth, several derived views" behaviour, spelled out. This is `FakeVitalsRepository`'s shape,
// including its two documented differences — this re-emits on every mutation where `StateFlow`
// would drop a value equal to the one it holds, and `bufferingNewest(1)` matches the conflation
// the real DAOs apply.

import Foundation
import SalusCommon
import SalusModel
import SalusTesting

@testable import FeatureAppointments

/// An in-memory `AppointmentsRepository` for tests that must not reach a database
/// (`FakeAppointmentsRepository.kt:14-52`).
///
/// `@unchecked Sendable` for `FixedSalusClock`'s reason: the state is mutable, and the lock is what
/// makes the promise true.
final class FakeAppointmentsRepository: AppointmentsRepository, @unchecked Sendable {
    private let zone: TimeZone
    private let lock = NSLock()
    private var appointments: [String: Appointment] = [:]
    private var observers: [UUID: @Sendable ([String: Appointment]) -> Void] = [:]

    /// `FakeAppointmentsRepository.kt:16` — the zone the fake derives instants in defaults to
    /// `Europe/Istanbul`, which is `FixedSalusClock.defaultZone`.
    init(zone: TimeZone = FixedSalusClock.defaultZone) {
        self.zone = zone
    }

    /// `FakeAppointmentsRepository.kt:20-22`.
    func setAppointments(_ items: Appointment...) {
        mutate { appointments in
            appointments = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        }
    }

    /// `FakeAppointmentsRepository.kt:24`.
    func current() -> [Appointment] {
        lock.withLock { Array(appointments.values) }
    }

    /// `FakeAppointmentsRepository.kt:26-32`.
    func observeUpcoming(from: Date) -> AsyncThrowingStream<[Appointment], any Error> {
        stream { appointments in
            appointments.values
                .filter { $0.status == .scheduled && $0.startsAt.instant(in: self.zone) >= from }
                .sorted(by: Self.soonestFirst)
        }
    }

    /// `FakeAppointmentsRepository.kt:34-40`.
    func observePast(before: Date) -> AsyncThrowingStream<[Appointment], any Error> {
        stream { appointments in
            appointments.values
                .filter { $0.status != .scheduled || $0.startsAt.instant(in: self.zone) < before }
                .sorted { Self.soonestFirst($1, $0) }
        }
    }

    /// `FakeAppointmentsRepository.kt:42`.
    func getAppointment(id: String) async throws -> Appointment? {
        lock.withLock { appointments[id] }
    }

    /// `FakeAppointmentsRepository.kt:44-45`.
    func observeAppointment(id: String) -> AsyncThrowingStream<Appointment?, any Error> {
        stream { appointments in appointments[id] }
    }

    /// `FakeAppointmentsRepository.kt:47-48`.
    func getScheduledAppointments() async throws -> [Appointment] {
        lock.withLock { appointments.values.filter { $0.status == .scheduled } }
    }

    /// `FakeAppointmentsRepository.kt:50-52`.
    func saveAppointment(_ appointment: Appointment) async throws {
        mutate { appointments in appointments[appointment.id] = appointment }
    }

    /// `FakeAppointmentsRepository.kt:54-56`.
    func deleteAppointment(id: String) async throws {
        mutate { appointments in appointments[id] = nil }
    }

    /// Kotlin's `sortedBy { it.startsAt }` reads `LocalDateTime`'s natural order.
    /// `SalusModel.LocalDateTime` is not `Comparable` — nothing in the port needed it yet — so the
    /// same order is spelled out here rather than widened into the model for a test fixture.
    private static func soonestFirst(_ lhs: Appointment, _ rhs: Appointment) -> Bool {
        (lhs.startsAt.date.epochDay, lhs.startsAt.minuteOfDay) < (rhs.startsAt.date.epochDay, rhs.startsAt.minuteOfDay)
    }

    /// The twin of `MutableStateFlow.map`: a derived view re-published whenever the map behind it
    /// changes, starting with what the map holds right now.
    private func stream<Value: Sendable>(
        _ derive: @escaping @Sendable ([String: Appointment]) -> Value
    ) -> AsyncThrowingStream<Value, any Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let token = UUID()
            lock.withLock {
                observers[token] = { snapshot in continuation.yield(derive(snapshot)) }
                continuation.yield(derive(appointments))
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                lock.withLock { _ = observers.removeValue(forKey: token) }
            }
        }
    }

    /// Mutates under the lock and publishes the result to every live observation, which is what
    /// assigning to `MutableStateFlow.value` does in one statement.
    private func mutate(_ change: (inout [String: Appointment]) -> Void) {
        lock.withLock {
            change(&appointments)
            for publish in observers.values {
                publish(appointments)
            }
        }
    }
}
