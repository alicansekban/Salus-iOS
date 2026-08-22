// Ported 1:1 from `core/database/.../entity/MedicationEntity.kt` (the `MedicationEntity` half).
// Conventions: see `ProfileRecord`.

import GRDB

/// A medication the profile takes. Cascade-deleted with its profile.
public struct MedicationRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "medications"

    public let id: String
    public let profileId: String
    public let name: String
    public let form: String
    public let strengthValue: Double?
    public let strengthUnit: String?
    public let colorToken: String
    public let instructions: String?
    public let stockCount: Double?
    public let stockThreshold: Double?
    public let startDateEpochDay: Int
    public let endDateEpochDay: Int?
    public let isActive: Bool
    public let createdAtEpochMs: Int64
    public let updatedAtEpochMs: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case name
        case form
        case strengthValue = "strength_value"
        case strengthUnit = "strength_unit"
        case colorToken = "color_token"
        case instructions
        case stockCount = "stock_count"
        case stockThreshold = "stock_threshold"
        case startDateEpochDay = "start_date"
        case endDateEpochDay = "end_date"
        case isActive = "is_active"
        case createdAtEpochMs = "created_at"
        case updatedAtEpochMs = "updated_at"
    }

    public init(
        id: String,
        profileId: String,
        name: String,
        form: String,
        strengthValue: Double?,
        strengthUnit: String?,
        colorToken: String,
        instructions: String?,
        stockCount: Double?,
        stockThreshold: Double?,
        startDateEpochDay: Int,
        endDateEpochDay: Int?,
        isActive: Bool,
        createdAtEpochMs: Int64,
        updatedAtEpochMs: Int64
    ) {
        self.id = id
        self.profileId = profileId
        self.name = name
        self.form = form
        self.strengthValue = strengthValue
        self.strengthUnit = strengthUnit
        self.colorToken = colorToken
        self.instructions = instructions
        self.stockCount = stockCount
        self.stockThreshold = stockThreshold
        self.startDateEpochDay = startDateEpochDay
        self.endDateEpochDay = endDateEpochDay
        self.isActive = isActive
        self.createdAtEpochMs = createdAtEpochMs
        self.updatedAtEpochMs = updatedAtEpochMs
    }
}
