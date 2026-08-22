// Ported 1:1 from `core/database/.../entity/AppointmentEntity.kt` (the `AppointmentEntity` half).
// The record conventions are documented once, on `ProfileRecord`.

import GRDB

/// A doctor's appointment. Cascade-deleted with its profile.
public struct AppointmentRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "appointments"

    public let id: String
    public let profileId: String
    public let title: String
    public let doctorName: String?
    public let specialty: String?
    public let location: String?
    public let notes: String?
    /// Wall-clock local date-time (ISO-8601, no offset). Together with `timeZoneId` this is the
    /// authoritative value; `startsAtEpochMs` is a derived query cache that must be recomputed on
    /// a system time or time-zone change (`AppointmentEntity.kt:32-33`).
    public let startsAtLocal: String
    public let timeZoneId: String
    public let startsAtEpochMs: Int64
    public let durationMinutes: Int
    public let status: String
    public let createdAtEpochMs: Int64
    public let updatedAtEpochMs: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case title
        case doctorName = "doctor_name"
        case specialty
        case location
        case notes
        case startsAtLocal = "starts_at_local"
        case timeZoneId = "tz_id"
        case startsAtEpochMs = "starts_at_epoch_ms"
        case durationMinutes = "duration_min"
        case status
        case createdAtEpochMs = "created_at"
        case updatedAtEpochMs = "updated_at"
    }

    public init(
        id: String,
        profileId: String,
        title: String,
        doctorName: String?,
        specialty: String?,
        location: String?,
        notes: String?,
        startsAtLocal: String,
        timeZoneId: String,
        startsAtEpochMs: Int64,
        durationMinutes: Int,
        status: String,
        createdAtEpochMs: Int64,
        updatedAtEpochMs: Int64
    ) {
        self.id = id
        self.profileId = profileId
        self.title = title
        self.doctorName = doctorName
        self.specialty = specialty
        self.location = location
        self.notes = notes
        self.startsAtLocal = startsAtLocal
        self.timeZoneId = timeZoneId
        self.startsAtEpochMs = startsAtEpochMs
        self.durationMinutes = durationMinutes
        self.status = status
        self.createdAtEpochMs = createdAtEpochMs
        self.updatedAtEpochMs = updatedAtEpochMs
    }
}
