// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// data/VitalsRepositoryImpl.kt`, weight members only — the blood-pressure and glucose overrides
// (`VitalsRepositoryImpl.kt:46-86`) arrive with iOS-M7 alongside their protocol members.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel

/// The only implementation of `VitalsRepository` (`VitalsRepositoryImpl.kt:15-45`).
///
/// A `final class` with immutable, `Sendable` storage, so the `Sendable` conformance the protocol
/// requires is checked rather than promised.
public final class VitalsRepositoryImpl: VitalsRepository {
    private let vitalsDao: VitalsDao
    private let profileId: String

    /// The `profileId` default is the value Koin passes at the single construction site
    /// (`VitalsModule.kt:23` — `VitalsRepositoryImpl(get(), SalusDatabase.DEFAULT_PROFILE_ID)`).
    /// It stays a parameter so a test can point the repository at another profile and prove the
    /// scoping is real.
    public init(vitalsDao: VitalsDao, profileId: String = SalusDatabase.defaultProfileId) {
        self.vitalsDao = vitalsDao
        self.profileId = profileId
    }

    /// `VitalsRepositoryImpl.kt:20-28`.
    ///
    /// Kotlin's `Flow.map` is element-wise and keeps the upstream's conflation; this rebuilds the
    /// stream because `AsyncThrowingStream` is a concrete type rather than a protocol, so
    /// `.bufferingNewest(1)` is repeated here to keep the DAO's Room-matching behaviour — a slow
    /// consumer is handed the current history, never a queue of superseded ones. The shape is
    /// `ProfileRepositoryImpl.observeProfile`'s.
    public func observeWeightHistory(
        from: Date,
        until: Date
    ) -> AsyncThrowingStream<[WeightEntry], any Error> {
        let records = vitalsDao.observeRange(
            profileId: profileId,
            type: VitalType.weight.rawValue,
            fromEpochMs: from.epochMilliseconds,
            untilEpochMs: until.epochMilliseconds
        )
        return Self.mapped(records) { try $0.map { record in try record.toWeightEntry() } }
    }

    /// `VitalsRepositoryImpl.kt:30-33`.
    public func observeLatestWeight() -> AsyncThrowingStream<WeightEntry?, any Error> {
        let records = vitalsDao.observeLatest(profileId: profileId, type: VitalType.weight.rawValue)
        return Self.mapped(records) { try $0?.toWeightEntry() }
    }

    /// `VitalsRepositoryImpl.kt:35-36`.
    ///
    /// The type check is not defensive padding: the three vital types share one table, so without
    /// it a blood-pressure row asked for by id would come back as a weight whose kilograms are a
    /// systolic reading.
    public func getWeightEntry(id: String) async throws -> WeightEntry? {
        guard
            let record = try await vitalsDao.getById(id),
            record.type == VitalType.weight.rawValue
        else {
            return nil
        }
        return try record.toWeightEntry()
    }

    /// `VitalsRepositoryImpl.kt:38-40`.
    public func saveWeightEntry(_ entry: WeightEntry) async throws {
        try await vitalsDao.upsert(entry.toRecord(profileId: profileId))
    }

    /// `VitalsRepositoryImpl.kt:42-44`.
    ///
    /// Deletion is by id alone, exactly as on Android: the DAO statement carries no type or
    /// profile clause, and an id is unique across the table.
    public func deleteWeightEntry(id: String) async throws {
        try await vitalsDao.deleteById(id)
    }

    /// The twin of `Flow.map` over a DAO observation, factored out because both observations above
    /// would otherwise be the same fifteen lines with one expression changed. A failure of the
    /// observation finishes the mapped stream with the same error instead of ending it silently —
    /// and so does a failure of the mapping itself, which is what a Kotlin `Flow.map` whose lambda
    /// throws does (`WeightEntryMapper.kt:16`, `TimeZone.of`).
    private static func mapped<Record: Sendable, Value: Sendable>(
        _ records: AsyncThrowingStream<Record, any Error>,
        _ transform: @escaping @Sendable (Record) throws -> Value
    ) -> AsyncThrowingStream<Value, any Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                do {
                    for try await record in records {
                        try continuation.yield(transform(record))
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
}
