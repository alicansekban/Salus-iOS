// Ported 1:1 from `core/database/.../entity/VitalsMeasurementEntity.kt`.
// Conventions: see `ProfileRecord`.

import GRDB

/// One vitals reading. A single table plus a type discriminator: `WEIGHT` (primary = kg),
/// `BLOOD_PRESSURE` (primary = systolic, secondary = diastolic, tertiary = pulse),
/// `BLOOD_GLUCOSE` (primary = value) — `VitalsMeasurementEntity.kt:9-10`.
/// Cascade-deleted with its profile.
public struct VitalsMeasurementRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "vitals_measurements"

    public let id: String
    public let profileId: String
    public let type: String
    public let measuredAtEpochMs: Int64
    public let timeZoneId: String
    public let valuePrimary: Double
    public let valueSecondary: Double?
    public let valueTertiary: Double?
    public let unit: String
    public let measurementContext: String?
    public let note: String?

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case type
        case measuredAtEpochMs = "measured_at_epoch_ms"
        case timeZoneId = "tz_id"
        case valuePrimary = "value_primary"
        case valueSecondary = "value_secondary"
        case valueTertiary = "value_tertiary"
        case unit
        case measurementContext = "measurement_context"
        case note
    }

    public init(
        id: String,
        profileId: String,
        type: String,
        measuredAtEpochMs: Int64,
        timeZoneId: String,
        valuePrimary: Double,
        valueSecondary: Double?,
        valueTertiary: Double?,
        unit: String,
        measurementContext: String?,
        note: String?
    ) {
        self.id = id
        self.profileId = profileId
        self.type = type
        self.measuredAtEpochMs = measuredAtEpochMs
        self.timeZoneId = timeZoneId
        self.valuePrimary = valuePrimary
        self.valueSecondary = valueSecondary
        self.valueTertiary = valueTertiary
        self.unit = unit
        self.measurementContext = measurementContext
        self.note = note
    }
}
