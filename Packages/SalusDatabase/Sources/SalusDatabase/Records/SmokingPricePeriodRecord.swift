// Ported 1:1 from `core/database/.../entity/SmokingPricePeriodEntity.kt` (Android `2045f43`).
// Conventions: see `ProfileRecord`.

import GRDB

/// The unit price from one day on, in minor units (contract §1). A price change adds a period
/// rather than rewriting history, so past savings keep the price they were earned at.
public struct SmokingPricePeriodRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "smoking_price_period"

    public let id: String
    public let effectiveFromEpochDay: Int64
    /// ≥ 0.
    public let unitCostMinor: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case effectiveFromEpochDay = "effective_from_epoch_day"
        case unitCostMinor = "unit_cost_minor"
    }

    public init(
        id: String,
        effectiveFromEpochDay: Int64,
        unitCostMinor: Int64
    ) {
        self.id = id
        self.effectiveFromEpochDay = effectiveFromEpochDay
        self.unitCostMinor = unitCostMinor
    }
}
