// Ported 1:1 from `core/database/.../entity/MedicationEntity.kt`
// (the `MedicationIntakeLogEntity` half). Conventions: see `ProfileRecord`.

import GRDB

/// One recorded dose. No `MISSED` row is ever written — the absence of a row is the absence of a
/// record, never a claim about someone's treatment (`CLAUDE.md`, banned health-claims vocabulary).
/// Cascade-deleted with its schedule.
public struct MedicationIntakeLogRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "medication_intake_logs"

    public let id: String
    public let scheduleId: String
    public let medicationId: String
    public let profileId: String
    public let scheduledDateEpochDay: Int
    public let scheduledMinutes: Int
    public let status: String
    public let takenAtEpochMs: Int64?
    public let snoozedUntilEpochMs: Int64?
    public let doseAmount: Double
    public let note: String?

    enum CodingKeys: String, CodingKey {
        case id
        case scheduleId = "schedule_id"
        case medicationId = "medication_id"
        case profileId = "profile_id"
        case scheduledDateEpochDay = "scheduled_date"
        case scheduledMinutes = "scheduled_minutes"
        case status
        case takenAtEpochMs = "taken_at_epoch_ms"
        case snoozedUntilEpochMs = "snoozed_until_epoch_ms"
        case doseAmount = "dose_amount"
        case note
    }

    public init(
        id: String,
        scheduleId: String,
        medicationId: String,
        profileId: String,
        scheduledDateEpochDay: Int,
        scheduledMinutes: Int,
        status: String,
        takenAtEpochMs: Int64?,
        snoozedUntilEpochMs: Int64?,
        doseAmount: Double,
        note: String?
    ) {
        self.id = id
        self.scheduleId = scheduleId
        self.medicationId = medicationId
        self.profileId = profileId
        self.scheduledDateEpochDay = scheduledDateEpochDay
        self.scheduledMinutes = scheduledMinutes
        self.status = status
        self.takenAtEpochMs = takenAtEpochMs
        self.snoozedUntilEpochMs = snoozedUntilEpochMs
        self.doseAmount = doseAmount
        self.note = note
    }
}
