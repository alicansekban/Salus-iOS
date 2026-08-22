// Ported 1:1 from
// `core/profile/src/main/kotlin/com/alicansekban/salus/core/profile/ProfileRepository.kt`.
//
// Kotlin's `Flow<Profile?>` becomes `AsyncThrowingStream<Profile?, any Error>`, not `AsyncStream`.
// A Room-backed `Flow` re-runs its query on every invalidation and lets a failure reach the
// collector; the DAO this repository maps (`ProfileDao.observeDefaultProfile`) already carries
// that, and a non-throwing stream here would have to swallow the error and end quietly — an empty
// screen where Android shows a failure. The `throws` is the port, not an addition.

import SalusModel

/// Read/write access to the single default profile seeded by the database migration
/// (Android: `SeedDefaultProfileCallback`).
///
/// This lives in `SalusProfile` rather than in a feature so that `FeatureSettings` and
/// `FeatureOnboarding` can both depend on it without importing each other — the twin of the
/// reason `:core:profile` exists on Android (`ProfileRepository.kt:6-13`).
public protocol ProfileRepository: Sendable {
    /// Emits the default profile, or nil before the migration has seeded it
    /// (`ProfileRepository.kt:17`).
    func observeProfile() -> AsyncThrowingStream<Profile?, any Error>

    /// `ProfileRepository.kt:19`.
    func getProfile() async throws -> Profile?

    /// Upserts the profile, preserving the row's original `created_at` when it exists
    /// (`ProfileRepository.kt:21-22`).
    func saveProfile(_ profile: Profile) async throws
}
