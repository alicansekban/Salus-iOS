// Ported 1:1 from `core/database/.../entity/ReminderAlarmEntity.kt`.
// Conventions: see `ProfileRecord`.

import GRDB

/// The scheduler's ledger: only the rolling window of upcoming occurrences is materialized here,
/// so rescheduling after a reboot or a time change is a pure scan of this table
/// (`ReminderAlarmEntity.kt:8-9`). No foreign key — a row outlives the thing it points at long
/// enough to be cancelled.
public struct ReminderAlarmRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "reminder_alarms"

    public let id: String
    public let type: String
    public let entityId: String
    /// Stable, deterministic occurrence identity, e.g. `"2026-09-01T08:00"`
    /// (`ReminderAlarmEntity.kt:21`).
    public let occurrenceKey: String
    public let triggerAtEpochMs: Int64
    /// Unique: on Android this is the `PendingIntent` request code, and two alarms sharing one
    /// would silently replace each other.
    public let requestCode: Int
    public let state: String

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case entityId = "entity_id"
        case occurrenceKey = "occurrence_key"
        case triggerAtEpochMs = "trigger_at_epoch_ms"
        case requestCode = "request_code"
        case state
    }

    public init(
        id: String,
        type: String,
        entityId: String,
        occurrenceKey: String,
        triggerAtEpochMs: Int64,
        requestCode: Int,
        state: String
    ) {
        self.id = id
        self.type = type
        self.entityId = entityId
        self.occurrenceKey = occurrenceKey
        self.triggerAtEpochMs = triggerAtEpochMs
        self.requestCode = requestCode
        self.state = state
    }
}
