// Ported 1:1 from `core/database/.../entity/SmokingPlanEntity.kt` (Android `2045f43`).
// Conventions: see `ProfileRecord`.

import GRDB

/// The user's plan (contract §1): QUIT or REDUCE, the product, the baseline, and the switches.
/// Single-row by contract — `SmokingDao.upsertPlan` keeps it that way (§8.6). The id is an
/// `IdGenerator` UUID, not a fixed id. Belongs to no profile.
public struct SmokingPlanRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "smoking_plan"

    public let id: String
    /// `QUIT` / `REDUCE`.
    public let mode: String
    /// `CIGARETTE` / `ROLLED` / `HEATED` / `VAPE`.
    public let productType: String
    public let baselineUnitsPerDay: Int
    /// NULL in QUIT.
    public let dailyLimit: Int?
    /// ISO 4217.
    public let currencyCode: String
    /// Never leaves the device: no export, AI prompt or PDF reads it.
    public let reason: String?
    public let notificationsEnabled: Bool
    /// The column defaults to 0, so a row written without the switch never starts nagging in the evening.
    public let eveningReminderEnabled: Bool
    public let createdAtMs: Int64
    public let tzId: String

    enum CodingKeys: String, CodingKey {
        case id
        case mode
        case productType = "product_type"
        case baselineUnitsPerDay = "baseline_units_per_day"
        case dailyLimit = "daily_limit"
        case currencyCode = "currency_code"
        case reason
        case notificationsEnabled = "notifications_enabled"
        case eveningReminderEnabled = "evening_reminder_enabled"
        case createdAtMs = "created_at_ms"
        case tzId = "tz_id"
    }

    public init(
        id: String,
        mode: String,
        productType: String,
        baselineUnitsPerDay: Int,
        dailyLimit: Int?,
        currencyCode: String,
        reason: String?,
        notificationsEnabled: Bool,
        eveningReminderEnabled: Bool,
        createdAtMs: Int64,
        tzId: String
    ) {
        self.id = id
        self.mode = mode
        self.productType = productType
        self.baselineUnitsPerDay = baselineUnitsPerDay
        self.dailyLimit = dailyLimit
        self.currencyCode = currencyCode
        self.reason = reason
        self.notificationsEnabled = notificationsEnabled
        self.eveningReminderEnabled = eveningReminderEnabled
        self.createdAtMs = createdAtMs
        self.tzId = tzId
    }
}
