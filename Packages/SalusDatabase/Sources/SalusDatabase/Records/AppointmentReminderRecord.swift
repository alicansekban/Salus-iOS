// Ported 1:1 from `core/database/.../entity/AppointmentEntity.kt`
// (the `AppointmentReminderEntity` half). Conventions: see `ProfileRecord`.

import GRDB

/// How long before an appointment to remind. Cascade-deleted with its appointment.
public struct AppointmentReminderRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "appointment_reminders"

    public let id: String
    public let appointmentId: String
    public let offsetMinutes: Int
    public let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case appointmentId = "appointment_id"
        case offsetMinutes = "offset_minutes"
        case enabled
    }

    public init(id: String, appointmentId: String, offsetMinutes: Int, enabled: Bool) {
        self.id = id
        self.appointmentId = appointmentId
        self.offsetMinutes = offsetMinutes
        self.enabled = enabled
    }
}
