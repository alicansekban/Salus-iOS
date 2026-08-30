// Ported 1:1 from the private `FakeProfileRepository` in
// `feature/onboarding/src/test/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingViewModelTest.kt:25-47`.
//
// Copied from `FeatureAppointments/Tests/.../FakeProfileRepository.swift` — the template-sanctioned
// copy: a test target never imports another package's test target, so a fake that two features both
// need is duplicated rather than shared. Two deltas from that copy, both from the Kotlin twin here:
//
//   1. It seeds with `OnboardingViewModelTest.kt:37-45`'s `seeded` profile by default (the
//      appointments copy starts on `nil`), because this test's `getProfile()` must answer the row
//      the migration seeds — the branch `finish()` actually takes in production.
//   2. It appends to the shared ``FinishOrderLog`` on `saveProfile`, so ruling 7's ordering is
//      testable.
//
// Kotlin backs the fake with a `MutableStateFlow<Profile?>` and returns it straight from
// `observeProfile()`. Swift has no `StateFlow`, so the value is guarded by a lock and every live
// observation is registered as a continuation fired on each mutation.

import Foundation
import SalusDatabase
import SalusModel
import SalusProfile

/// An in-memory ``ProfileRepository`` for tests that must not reach a database
/// (`OnboardingViewModelTest.kt:25-47`).
///
/// `@unchecked Sendable` for `FixedSalusClock`'s reason: the state is mutable, and the lock is what
/// makes the promise true.
final class FakeProfileRepository: ProfileRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var profileValue: Profile?
    private var continuations: [UUID: AsyncThrowingStream<Profile?, any Error>.Continuation] = [:]
    private let orderLog: FinishOrderLog?

    /// `OnboardingViewModelTest.kt:26` — the flow starts on the seeded row.
    init(profile: Profile? = FakeProfileRepository.seeded, orderLog: FinishOrderLog? = nil) {
        profileValue = profile
        self.orderLog = orderLog
    }

    /// `OnboardingViewModelTest.kt:37-45` — the row the v1 migration seeds.
    static let seeded = Profile(
        id: SalusDatabase.defaultProfileId,
        displayName: "",
        birthDate: nil,
        sex: nil,
        heightCm: nil,
        healthNotes: nil,
        isDefault: true
    )

    /// The twin of reading `profiles.value` in an assertion.
    var profile: Profile? {
        lock.lock()
        defer { lock.unlock() }
        return profileValue
    }

    /// `OnboardingViewModelTest.kt:28`.
    func observeProfile() -> AsyncThrowingStream<Profile?, any Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            let current = profileValue
            lock.unlock()

            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id)
            }
        }
    }

    /// `OnboardingViewModelTest.kt:30`.
    func getProfile() async throws -> Profile? {
        profile
    }

    /// `OnboardingViewModelTest.kt:32-34`.
    func saveProfile(_ profile: Profile) async throws {
        setProfile(profile)
        orderLog?.record(.profile)
    }

    /// The twin of `profiles.value = …` — flips the profile and pushes it to every open stream.
    func setProfile(_ profile: Profile?) {
        lock.lock()
        profileValue = profile
        let pending = Array(continuations.values)
        lock.unlock()
        for continuation in pending {
            continuation.yield(profile)
        }
    }

    private func removeContinuation(_ id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }
}
