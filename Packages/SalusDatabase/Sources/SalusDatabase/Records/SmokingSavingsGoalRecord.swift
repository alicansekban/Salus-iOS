// Ported 1:1 from `core/database/.../entity/SmokingSavingsGoalEntity.kt` (Android `2045f43`).
// Conventions: see `ProfileRecord`.

import GRDB

/// What the user is saving towards (contract §1). The newest row is the active goal, reached or
/// not (§8.6), so a reached goal stays on the card until the next one is set.
public struct SmokingSavingsGoalRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "smoking_savings_goal"

    public let id: String
    public let title: String
    /// > 0.
    public let targetMinor: Int64
    public let createdAtMs: Int64
    public let achievedAtMs: Int64?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case targetMinor = "target_minor"
        case createdAtMs = "created_at_ms"
        case achievedAtMs = "achieved_at_ms"
    }

    public init(
        id: String,
        title: String,
        targetMinor: Int64,
        createdAtMs: Int64,
        achievedAtMs: Int64?
    ) {
        self.id = id
        self.title = title
        self.targetMinor = targetMinor
        self.createdAtMs = createdAtMs
        self.achievedAtMs = achievedAtMs
    }
}
