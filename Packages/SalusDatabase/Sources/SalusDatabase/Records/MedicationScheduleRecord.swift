// Ported 1:1 from `core/database/.../entity/MedicationEntity.kt`
// (the `MedicationScheduleEntity` half). Conventions: see `ProfileRecord`.

import GRDB

/// When a medication is due. Cascade-deleted with its medication.
public struct MedicationScheduleRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "medication_schedules"

    public let id: String
    public let medicationId: String
    public let recurrence: String
    /// Bit 0 = Monday … bit 6 = Sunday; only meaningful for `DAYS_OF_WEEK`
    /// (`MedicationEntity.kt:55`).
    public let daysOfWeekMask: Int
    public let intervalDays: Int?
    public let anchorDateEpochDay: Int
    /// Local time-of-day semantics, so a dose survives DST; never stored as a UTC instant
    /// (`MedicationEntity.kt:59`).
    public let timeOfDayMinutes: Int
    public let doseAmount: Double
    public let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case medicationId = "medication_id"
        case recurrence
        case daysOfWeekMask = "days_of_week_mask"
        case intervalDays = "interval_days"
        case anchorDateEpochDay = "anchor_date"
        case timeOfDayMinutes = "time_of_day_minutes"
        case doseAmount = "dose_amount"
        case isActive = "is_active"
    }

    public init(
        id: String,
        medicationId: String,
        recurrence: String,
        daysOfWeekMask: Int,
        intervalDays: Int?,
        anchorDateEpochDay: Int,
        timeOfDayMinutes: Int,
        doseAmount: Double,
        isActive: Bool
    ) {
        self.id = id
        self.medicationId = medicationId
        self.recurrence = recurrence
        self.daysOfWeekMask = daysOfWeekMask
        self.intervalDays = intervalDays
        self.anchorDateEpochDay = anchorDateEpochDay
        self.timeOfDayMinutes = timeOfDayMinutes
        self.doseAmount = doseAmount
        self.isActive = isActive
    }
}
