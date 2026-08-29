// Ported 1:1 from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/data/
// CycleRepositoryImpl.kt`.
//
// Two departures from the Kotlin, both deliberate:
//
//  - **`saveDayLog` is one write, not two** (recorded divergence (a), stated on
//    `CycleDao.saveDailyEntry(_:links:)`). Android issues `upsertDailyEntry` and
//    `replaceEntrySymptoms` as two statements, so a reader between them sees the new day beside
//    the symptom set of its previous version. Here they share one transaction. The semantics are
//    otherwise Android's, down to the *replace* (not merge) of the symptom set.
//  - **The type is a `struct`, and internal.** Nothing outside this module constructs it — the
//    feature's module factory, which lives in this package, is its one construction site — and its
//    two stored properties are immutable and `Sendable`, so the protocol's `Sendable` conformance
//    is checked rather than promised. `MedicationsRepositoryImpl`'s shape.
//
// `observeSymptoms` is where the port needs the most care: Kotlin's `onStart` runs the seeding
// *before* Room's query is collected, so the first thing a collector sees is the seeded catalog,
// never an empty list followed by eight rows. The Swift twin therefore seeds inside the stream's
// own task and only then asks the DAO for its observation — the ordering is the behaviour, not an
// implementation detail. The wrapper is otherwise `SalusCommon.mapped`'s, restated because the
// prologue has to run inside the same task the consumer's cancellation tears down.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel

/// The only implementation of ``CycleRepository`` (`CycleRepositoryImpl.kt:14-84`).
struct CycleRepositoryImpl: CycleRepository {
    private let cycleDao: CycleDao
    private let profileId: String

    /// The `profileId` default is the value Koin passes at the single construction site
    /// (`SalusDatabase.DEFAULT_PROFILE_ID`). It stays a parameter so a test can point the
    /// repository at another profile and prove the scoping is real.
    init(cycleDao: CycleDao, profileId: String = SalusDatabase.defaultProfileId) {
        self.cycleDao = cycleDao
        self.profileId = profileId
    }

    /// `CycleRepositoryImpl.kt:19-22`. The DAO's `ORDER BY start_date DESC` is the order; the
    /// mapper does not re-sort.
    func observePeriods() -> AsyncThrowingStream<[CyclePeriod], any Error> {
        mapped(cycleDao.observePeriods(profileId: profileId)) { records in
            records.map { CycleMappers.toDomain($0) }
        }
    }

    /// `CycleRepositoryImpl.kt:24-25`.
    func getOpenPeriod() async throws -> CyclePeriod? {
        try await cycleDao.getOpenPeriod(profileId: profileId).map { CycleMappers.toDomain($0) }
    }

    /// `CycleRepositoryImpl.kt:27-28`.
    func getPeriodStartingOn(_ date: LocalDate) async throws -> CyclePeriod? {
        try await cycleDao
            .getPeriodByStart(profileId: profileId, startEpochDay: date.epochDay)
            .map { CycleMappers.toDomain($0) }
    }

    /// `CycleRepositoryImpl.kt:30-32`.
    func savePeriod(_ period: CyclePeriod) async throws {
        try await cycleDao.upsertPeriod(CycleMappers.toRecord(period, profileId: profileId))
    }

    /// `CycleRepositoryImpl.kt:34-36`. The day logs are not touched: a deleted period removes the
    /// recorded span, not the days the user logged inside it.
    func deletePeriod(id: String) async throws {
        try await cycleDao.deletePeriodById(id)
    }

    /// The catalog, seeded on the first collection if it is empty (`CycleRepositoryImpl.kt:38-42`,
    /// `:55-59`) — the `onStart` twin; see the file header for why the seeding runs before the
    /// DAO's observation is asked for rather than beside it.
    func observeSymptoms() -> AsyncThrowingStream<[Symptom], any Error> {
        let cycleDao = cycleDao
        return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                do {
                    try await Self.seedSymptomCatalogIfEmpty(cycleDao)
                    for try await records in cycleDao.observeSymptoms() {
                        continuation.yield(records.map { CycleMappers.toDomain($0) })
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // A consumer that stops reading must stop the observation — and the seeding — too.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// `CycleRepositoryImpl.kt:44-48`. A day nobody logged is `nil` rather than an empty log, so
    /// the editor opens blank instead of showing a record that does not exist.
    func getDayLog(on date: LocalDate) async throws -> CycleDayLog? {
        guard let entry = try await cycleDao.getDailyEntry(
            profileId: profileId,
            epochDay: date.epochDay
        ) else {
            return nil
        }
        let symptomIds = try await Set(cycleDao.getEntrySymptoms(entryId: entry.id).map(\.symptomId))
        return CycleMappers.toDomain(entry, symptomIds: symptomIds)
    }

    /// `CycleRepositoryImpl.kt:50-53`, as one transaction — see the file header, divergence (a).
    func saveDayLog(_ log: CycleDayLog) async throws {
        try await cycleDao.saveDailyEntry(
            CycleMappers.toRecord(log, profileId: profileId),
            links: CycleMappers.toSymptomLinks(log)
        )
    }

    /// `CycleRepositoryImpl.kt:55-59`. Guarded by the stored count rather than by a flag this
    /// process holds, so a second screen — or the same screen after a relaunch — re-runs the guard
    /// and writes nothing.
    private static func seedSymptomCatalogIfEmpty(_ cycleDao: CycleDao) async throws {
        if try await cycleDao.countSymptoms() == 0 {
            try await cycleDao.upsertSymptoms(seedSymptoms)
        }
    }

    /// Starter symptom catalog: ids are stable/deterministic, name keys are string-resource keys
    /// resolved by the UI (never display text) (`CycleRepositoryImpl.kt:61-83`).
    ///
    /// Declaration order is Android's and is not the order they are read back in — the DAO sorts
    /// by `name_key`, so `acne` leads the emission while `cramps` leads this list.
    static let seedSymptoms = [
        seedSymptom("cramps"),
        seedSymptom("headache"),
        seedSymptom("mood_swings"),
        seedSymptom("bloating"),
        seedSymptom("fatigue"),
        seedSymptom("tender_breasts"),
        seedSymptom("acne"),
        seedSymptom("back_pain")
    ]

    /// `CycleRepositoryImpl.kt:77-82`. The id is the name key with `_` swapped for `-`, so
    /// `mood_swings` is stored as `symptom-mood-swings`.
    private static func seedSymptom(_ nameKey: String) -> SymptomRecord {
        SymptomRecord(
            id: "symptom-" + nameKey.replacingOccurrences(of: "_", with: "-"),
            nameKey: nameKey,
            isCustom: false,
            iconToken: nil
        )
    }
}
