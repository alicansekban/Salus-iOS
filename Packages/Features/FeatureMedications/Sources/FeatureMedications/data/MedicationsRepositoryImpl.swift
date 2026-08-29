// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/data/MedicationRepositoryImpl.kt`.
//
// Two departures from the Kotlin, both deliberate:
//
//  - **`saveMedication` is one write, not three** (recorded divergence (d)). Android issues
//    `upsert`, `upsertSchedules` and `deactivateSchedulesExcept` as three statements, so a reader
//    between them sees the new medication beside the schedule set of its previous version. Here
//    `MedicationDao.saveWithSchedules` runs all three inside one transaction. The semantics are
//    otherwise Android's, down to the *replace* (not merge) of the active schedule set.
//  - **The type is a `struct`, and internal.** Nothing outside this module constructs it — the
//    feature's module factory, which lives in this package, is its one construction site — and its
//    three stored properties are immutable and `Sendable`, so the protocol's `Sendable`
//    conformance is checked rather than promised.

import Foundation
import SalusCommon
import SalusDatabase

/// The only implementation of `MedicationRepository` (`MedicationRepositoryImpl.kt:16-124`).
struct MedicationsRepositoryImpl: MedicationRepository {
    /// `MedicationRepositoryImpl.kt:121-123` — the colour a medication gets until the editor's picker
    /// gives it another one, and the value an edit falls back to only when there is no stored row.
    private static let defaultColorToken = "primary"

    private let dao: MedicationDao
    private let clock: any SalusClock
    private let profileId: String

    /// The `profileId` default is the value Koin passes at the single construction site
    /// (`SalusDatabase.DEFAULT_PROFILE_ID`). It stays a parameter so a test can point the
    /// repository at another profile and prove the scoping is real — `AppointmentsRepositoryImpl`'s
    /// shape.
    init(dao: MedicationDao, clock: any SalusClock, profileId: String = SalusDatabase.defaultProfileId) {
        self.dao = dao
        self.clock = clock
        self.profileId = profileId
    }

    /// `MedicationRepositoryImpl.kt:22-34`.
    ///
    /// One profile-wide schedule observation serves the whole list, which is why the DAO exposes a
    /// joined query rather than one observation per medication. The medications keep the DAO's
    /// order (`ORDER BY name`); the schedules keep theirs within each group.
    func observeActiveMedications() -> AsyncThrowingStream<[MedicationWithSchedules], any Error> {
        latestOfBoth(
            dao.observeActive(profileId: profileId),
            dao.observeAllActiveSchedules(profileId: profileId)
        ) { medications, schedules in
            Self.grouped(medications: medications, schedules: schedules)
        }
    }

    /// `MedicationRepositoryImpl.kt:36-47`.
    ///
    /// The nil emission is what closes the detail screen once the medication it is showing is
    /// deleted, so it is the one emission that must not be swallowed.
    func observeMedication(id: String) -> AsyncThrowingStream<MedicationWithSchedules?, any Error> {
        latestOfBoth(
            dao.observeById(id),
            dao.observeActiveSchedulesFor(medicationId: id)
        ) { record, schedules -> MedicationWithSchedules? in
            guard let record else { return nil }
            return MedicationWithSchedules(
                medication: record.toDomain(),
                schedules: schedules.map { $0.toDomain() }
            )
        }
    }

    /// `MedicationRepositoryImpl.kt:49-55`.
    func getMedication(id: String) async throws -> MedicationWithSchedules? {
        guard let record = try await dao.getById(id) else { return nil }
        return try await MedicationWithSchedules(
            medication: record.toDomain(),
            schedules: dao.getActiveSchedulesFor(medicationId: id).map { $0.toDomain() }
        )
    }

    /// `MedicationRepositoryImpl.kt:57-73`.
    func saveMedication(_ medication: Medication, schedules: [MedicationSchedule]) async throws {
        let existing = try await dao.getById(medication.id)
        let nowEpochMs = clock.nowEpochMilliseconds()
        try await dao.saveWithSchedules(
            medication.toRecord(
                profileId: profileId,
                colorToken: existing?.colorToken ?? Self.defaultColorToken,
                createdAtEpochMs: existing?.createdAtEpochMs ?? nowEpochMs,
                updatedAtEpochMs: nowEpochMs,
                // The toggle has one write path, `setRemindersEnabled`: the editor rebuilds
                // the model from its form and must not overwrite a switch flipped elsewhere.
                remindersEnabled: existing?.remindersEnabled ?? medication.remindersEnabled
            ),
            schedules: schedules.map { $0.toRecord() }
        )
    }

    /// `MedicationRepositoryImpl.kt:75-77`.
    func deleteMedication(id: String) async throws {
        // `medication_schedules` rows cascade with the medication row, and
        // `medication_intake_logs` rows cascade with them.
        try await dao.deleteById(id)
    }

    /// `MedicationRepositoryImpl.kt:79-87`.
    func getAllActiveMedications() async throws -> [MedicationWithSchedules] {
        let schedules = try await dao.getAllActiveSchedules(profileId: profileId)
        let medications = try await dao.getActive(profileId: profileId)
        return Self.grouped(medications: medications, schedules: schedules)
    }

    /// `MedicationRepositoryImpl.kt:89-90`.
    func getSchedule(scheduleId: String) async throws -> MedicationSchedule? {
        try await dao.getScheduleById(scheduleId)?.toDomain()
    }

    /// `MedicationRepositoryImpl.kt:92-93`.
    func getLog(scheduleId: String, epochDay: Int, minuteOfDay: Int) async throws -> IntakeLog? {
        try await dao.getIntakeLogForOccurrence(
            scheduleId: scheduleId,
            epochDay: epochDay,
            minutes: minuteOfDay
        )?.toDomain()
    }

    /// `MedicationRepositoryImpl.kt:95-104`.
    func upsertLog(_ log: IntakeLog) async throws {
        // The (schedule, day, minutes) unique index is the true identity; reuse the stored
        // row id so a log created from the notification receiver and one from the UI merge.
        let existing = try await dao.getIntakeLogForOccurrence(
            scheduleId: log.scheduleId,
            epochDay: log.epochDay,
            minutes: log.minuteOfDay
        )
        guard let existing else {
            // An insert, not an upsert, on both platforms: a duplicate occurrence has to surface
            // as the unique index's constraint error rather than be merged behind the caller.
            try await dao.insertIntakeLog(log.toRecord(profileId: profileId))
            return
        }
        try await dao.updateIntakeLog(log.withId(existing.id).toRecord(profileId: profileId))
    }

    /// `MedicationRepositoryImpl.kt:106-108`. No sorting: the DAO's query carries no `ORDER BY`
    /// on either platform, and an order the source does not promise is not one to invent here.
    func observeLogsBetween(
        fromEpochDay: Int,
        toEpochDay: Int
    ) -> AsyncThrowingStream<[IntakeLog], any Error> {
        mapped(
            dao.observeIntakeLogsBetween(
                profileId: profileId,
                fromEpochDay: fromEpochDay,
                toEpochDay: toEpochDay
            )
        ) { records in records.map { $0.toDomain() } }
    }

    /// `MedicationRepositoryImpl.kt:110-111`.
    func getLogsBetween(fromEpochDay: Int, toEpochDay: Int) async throws -> [IntakeLog] {
        try await dao.getIntakeLogsBetween(
            profileId: profileId,
            fromEpochDay: fromEpochDay,
            toEpochDay: toEpochDay
        ).map { $0.toDomain() }
    }

    /// `MedicationRepositoryImpl.kt:113-115`.
    func decrementStock(medicationId: String, amount: Double) async throws {
        try await dao.decrementStock(id: medicationId, amount: amount)
    }

    /// `MedicationRepositoryImpl.kt:117-119` — the only write path for the flag, which is why
    /// `saveMedication` reads the stored value back instead of taking the model's.
    func setRemindersEnabled(medicationId: String, enabled: Bool) async throws {
        try await dao.setRemindersEnabled(
            id: medicationId,
            enabled: enabled,
            updatedAtEpochMs: clock.nowEpochMilliseconds()
        )
    }

    /// The `groupBy { it.medicationId }` both list reads share
    /// (`MedicationRepositoryImpl.kt:27-33`, `:80-86`). The medication order is the DAO's; a
    /// medication with no active schedule keeps its place with an empty list rather than dropping
    /// out of the list.
    private static func grouped(
        medications: [MedicationRecord],
        schedules: [MedicationScheduleRecord]
    ) -> [MedicationWithSchedules] {
        let schedulesByMedication = Dictionary(grouping: schedules, by: \.medicationId)
        return medications.map { record in
            MedicationWithSchedules(
                medication: record.toDomain(),
                schedules: (schedulesByMedication[record.id] ?? []).map { $0.toDomain() }
            )
        }
    }
}

extension IntakeLog {
    /// The twin of Kotlin's `data class` `copy(id = …)` (`MedicationRepositoryImpl.kt:102`), the
    /// one field `upsertLog` overrides. Swift synthesises no `copy`, and a memberwise call here
    /// would bury the field that changes under nine that do not.
    fileprivate func withId(_ id: String) -> IntakeLog {
        IntakeLog(
            id: id,
            scheduleId: scheduleId,
            medicationId: medicationId,
            epochDay: epochDay,
            minuteOfDay: minuteOfDay,
            status: status,
            takenAtEpochMs: takenAtEpochMs,
            snoozedUntilEpochMs: snoozedUntilEpochMs,
            doseAmount: doseAmount,
            note: note
        )
    }
}
