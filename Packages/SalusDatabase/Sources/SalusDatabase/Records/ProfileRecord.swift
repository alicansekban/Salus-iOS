// Ported 1:1 from `core/database/.../entity/ProfileEntity.kt`.
//
// Two conventions hold for all thirteen records in this directory:
//
// * Property names are the Kotlin property names (`birthDateEpochDay`, not `birthDate`), and
//   `CodingKeys` carry the Room column names. The column string is the persisted contract; the
//   Swift name is free to say what the number means.
// * A column keeps the primitive type the Kotlin entity stores it as. `sex` is a `String` here
//   even though `SalusModel` has a `Sex` enum, exactly as `ProfileEntity` keeps it a `String`:
//   the mapping to a domain enum belongs to the repository, and a record that rejects an unknown
//   value would turn a forward-compatible database into an unreadable one.
//
// Kotlin `Long` becomes `Int64` and Kotlin `Int` becomes `Int`, which keeps the epoch-millisecond
// and epoch-day columns as distinguishable here as they are on Android.

import GRDB

/// A person the log belongs to. v1 seeds exactly one, `SalusDatabase.defaultProfileId`.
public struct ProfileRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "profiles"

    public let id: String
    public let displayName: String
    public let birthDateEpochDay: Int?
    public let sex: String?
    public let heightCm: Double?
    /// Chronic conditions and allergies, added by the 1 → 2 migration; NULL for older rows.
    public let healthNotes: String?
    public let isDefault: Bool
    public let createdAtEpochMs: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case birthDateEpochDay = "birth_date"
        case sex
        case heightCm = "height_cm"
        case healthNotes = "health_notes"
        case isDefault = "is_default"
        case createdAtEpochMs = "created_at"
    }

    public init(
        id: String,
        displayName: String,
        birthDateEpochDay: Int?,
        sex: String?,
        heightCm: Double?,
        healthNotes: String?,
        isDefault: Bool,
        createdAtEpochMs: Int64
    ) {
        self.id = id
        self.displayName = displayName
        self.birthDateEpochDay = birthDateEpochDay
        self.sex = sex
        self.heightCm = heightCm
        self.healthNotes = healthNotes
        self.isDefault = isDefault
        self.createdAtEpochMs = createdAtEpochMs
    }
}
