// Ported 1:1 from
// `core/profile/src/main/kotlin/com/alicansekban/salus/core/profile/ProfileRepositoryImpl.kt`.
//
// The Kotlin class is `internal` because Koin builds it behind the interface. There is no DI
// container in the tree yet, so this one is `public`: the app shell has to be able to construct it
// once that wiring lands. The mappers above stay internal, so nothing about the record shape
// escapes with it.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel

/// The only implementation of `ProfileRepository` (`ProfileRepositoryImpl.kt:11-27`).
///
/// A `final class` with immutable, `Sendable` storage, so the `Sendable` conformance
/// `ProfileRepository` requires is checked rather than promised.
public final class ProfileRepositoryImpl: ProfileRepository {
    private let profileDao: ProfileDao
    private let clock: any SalusClock

    public init(profileDao: ProfileDao, clock: any SalusClock) {
        self.profileDao = profileDao
        self.clock = clock
    }

    /// `ProfileRepositoryImpl.kt:16-17` — `profileDao.observeDefaultProfile().map { it?.toDomain() }`.
    ///
    /// Kotlin's `Flow.map` is element-wise and keeps the upstream's conflation; this rebuilds the
    /// stream because `AsyncThrowingStream` is a concrete type rather than a protocol, so
    /// `.bufferingNewest(1)` is repeated here to keep the DAO's Room-matching behaviour: a slow
    /// consumer is handed the current profile, never a queue of superseded ones. A failure of the
    /// observation finishes this stream with the same error instead of ending it silently.
    public func observeProfile() -> AsyncThrowingStream<Profile?, any Error> {
        let records = profileDao.observeDefaultProfile()

        return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                do {
                    for try await record in records {
                        continuation.yield(record?.toDomain())
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // A consumer that stops reading must stop the observation too.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// `ProfileRepositoryImpl.kt:19`.
    public func getProfile() async throws -> Profile? {
        try await profileDao.getDefaultProfile()?.toDomain()
    }

    /// `ProfileRepositoryImpl.kt:21-26`.
    public func saveProfile(_ profile: Profile) async throws {
        // The seeded row already carries a created_at; only a genuinely new row gets "now".
        let createdAt = try await profileDao.getById(profile.id)?.createdAtEpochMs
            ?? Self.epochMilliseconds(clock.now())
        try await profileDao.upsert(profile.toRecord(createdAtEpochMs: createdAt))
    }

    /// The twin of `Instant.toEpochMilliseconds()`: whole milliseconds, truncated rather than
    /// rounded, so a stamp never lands in the future.
    private static func epochMilliseconds(_ instant: Date) -> Int64 {
        Int64(instant.timeIntervalSince1970 * 1000)
    }
}
