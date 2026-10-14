// Ported 1:1 from `core/database/.../entity/SmokingEventEntity.kt` (Android `2045f43`).
// Conventions: see `ProfileRecord`.

import GRDB

/// One logged smoke or resisted craving (contract §1). `epochDay` is computed once, in the
/// event's own `tzId`, and stored — every reading buckets by it (§8.5). Deleting the attempt it
/// belongs to sets `attemptId` to NULL rather than deleting the event (`ON DELETE SET NULL`).
public struct SmokingEventRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "smoking_event"

    public let id: String
    /// `SMOKED` / `CRAVING_RESISTED`.
    public let type: String
    public let occurredAtMs: Int64
    public let tzId: String
    public let epochDay: Int64
    /// SMOKED ≥ 1, or 0 for the REDUCE "none today" marker; NULL for CRAVING_RESISTED.
    public let units: Int?
    public let trigger: String?
    /// 1–5.
    public let intensity: Int?
    /// The product at event time, so a later product switch does not rewrite the log.
    public let productType: String
    public let attemptId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case occurredAtMs = "occurred_at_ms"
        case tzId = "tz_id"
        case epochDay = "epoch_day"
        case units
        case trigger
        case intensity
        case productType = "product_type"
        case attemptId = "attempt_id"
    }

    public init(
        id: String,
        type: String,
        occurredAtMs: Int64,
        tzId: String,
        epochDay: Int64,
        units: Int?,
        trigger: String?,
        intensity: Int?,
        productType: String,
        attemptId: String?
    ) {
        self.id = id
        self.type = type
        self.occurredAtMs = occurredAtMs
        self.tzId = tzId
        self.epochDay = epochDay
        self.units = units
        self.trigger = trigger
        self.intensity = intensity
        self.productType = productType
        self.attemptId = attemptId
    }
}
