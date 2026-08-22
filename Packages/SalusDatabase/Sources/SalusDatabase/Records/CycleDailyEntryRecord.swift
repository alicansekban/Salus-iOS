// Ported 1:1 from `core/database/.../entity/CycleEntity.kt` (the `CycleDailyEntryEntity` part).
// Conventions: see `ProfileRecord`.

import GRDB

/// One day's cycle log. Unique per profile and day. Cascade-deleted with its profile.
public struct CycleDailyEntryRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "cycle_daily_entries"

    public let id: String
    public let profileId: String
    public let dateEpochDay: Int
    public let flow: String?
    public let mood: String?
    public let note: String?

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case dateEpochDay = "date"
        case flow
        case mood
        case note
    }

    public init(id: String, profileId: String, dateEpochDay: Int, flow: String?, mood: String?, note: String?) {
        self.id = id
        self.profileId = profileId
        self.dateEpochDay = dateEpochDay
        self.flow = flow
        self.mood = mood
        self.note = note
    }
}
