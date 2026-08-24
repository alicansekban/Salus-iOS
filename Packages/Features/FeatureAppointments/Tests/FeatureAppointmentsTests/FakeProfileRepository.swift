// Ported 1:1 from `feature/appointments/src/test/kotlin/com/alicansekban/salus/feature/
// appointments/FakeProfileRepository.kt`.
//
// Kotlin backs the fake with a `MutableStateFlow<Profile?>` and returns it straight from
// `observeProfile()`. Swift has no `StateFlow`, so the value is guarded by a lock and every live
// observation is registered as a callback fired on each mutation — the same shape
// `FakeAppointmentsRepository` already uses in this target, minus the derived views it needs and
// this one does not.
//
// Kotlin's `profiles.value = …` becomes `setProfile(_:)`: a settable property would have to be
// `nonisolated(unsafe)` or lock-guarded behind a computed pair, and the fake already spells its
// one mutation as a method the way `setAppointments` does.

import Foundation
import SalusModel
import SalusProfile

/// An in-memory `ProfileRepository` for tests that must not reach a database
/// (`FakeProfileRepository.kt:8-22`).
///
/// `@unchecked Sendable` for `FixedSalusClock`'s reason: the state is mutable, and the lock is what
/// makes the promise true.
final class FakeProfileRepository: ProfileRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var profile: Profile?
    private var observers: [UUID: @Sendable (Profile?) -> Void] = [:]

    /// `FakeProfileRepository.kt:9` — the flow starts on `null`, the state before the migration
    /// has seeded the default profile.
    init(profile: Profile? = nil) {
        self.profile = profile
    }

    /// The twin of `profiles.value = …`.
    func setProfile(_ profile: Profile?) {
        lock.withLock {
            self.profile = profile
            for publish in observers.values {
                publish(profile)
            }
        }
    }

    /// `FakeProfileRepository.kt:12`.
    func observeProfile() -> AsyncThrowingStream<Profile?, any Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let token = UUID()
            lock.withLock {
                observers[token] = { profile in continuation.yield(profile) }
                continuation.yield(profile)
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                lock.withLock { _ = observers.removeValue(forKey: token) }
            }
        }
    }

    /// `FakeProfileRepository.kt:14`.
    func getProfile() async throws -> Profile? {
        lock.withLock { profile }
    }

    /// `FakeProfileRepository.kt:16-18`.
    func saveProfile(_ profile: Profile) async throws {
        setProfile(profile)
    }
}

/// `FakeProfileRepository.kt:21-29` — the fixture every profile-reading test starts from.
func testProfile(healthNotes: String?) -> Profile {
    Profile(
        id: "default-profile",
        displayName: "Ada",
        birthDate: nil,
        sex: nil,
        heightCm: nil,
        healthNotes: healthNotes,
        isDefault: true
    )
}
