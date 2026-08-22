// Ported 1:1 from `core/database/.../entity/CycleEntity.kt` (the `CyclePeriodEntity` part).
// Conventions: see `ProfileRecord`.

import GRDB

/// A recorded period. Only real records live here — predictions are always computed, never
/// persisted (`CycleEntity.kt:9`). Cascade-deleted with its profile.
public struct CyclePeriodRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "cycle_periods"

    public let id: String
    public let profileId: String
    public let startDateEpochDay: Int
    public let endDateEpochDay: Int?
    public let flowPeak: String?
    public let note: String?
    public let createdAtEpochMs: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case startDateEpochDay = "start_date"
        case endDateEpochDay = "end_date"
        case flowPeak = "flow_peak"
        case note
        case createdAtEpochMs = "created_at"
    }

    public init(
        id: String,
        profileId: String,
        startDateEpochDay: Int,
        endDateEpochDay: Int?,
        flowPeak: String?,
        note: String?,
        createdAtEpochMs: Int64
    ) {
        self.id = id
        self.profileId = profileId
        self.startDateEpochDay = startDateEpochDay
        self.endDateEpochDay = endDateEpochDay
        self.flowPeak = flowPeak
        self.note = note
        self.createdAtEpochMs = createdAtEpochMs
    }
}
