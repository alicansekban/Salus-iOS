// Ported 1:1 from `core/database/.../entity/SmokingQuitAttemptEntity.kt` (Android `2045f43`).
// Conventions: see `ProfileRecord`.

import GRDB

/// One QUIT attempt (contract §1). An open attempt has no `endedAtMs`.
public struct SmokingQuitAttemptRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "smoking_quit_attempt"

    public let id: String
    public let startedAtMs: Int64
    public let tzId: String
    /// NULL while the attempt is active.
    public let endedAtMs: Int64?
    /// `RESTARTED` / `SWITCHED_TO_REDUCE`.
    public let endReason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case startedAtMs = "started_at_ms"
        case tzId = "tz_id"
        case endedAtMs = "ended_at_ms"
        case endReason = "end_reason"
    }

    public init(
        id: String,
        startedAtMs: Int64,
        tzId: String,
        endedAtMs: Int64?,
        endReason: String?
    ) {
        self.id = id
        self.startedAtMs = startedAtMs
        self.tzId = tzId
        self.endedAtMs = endedAtMs
        self.endReason = endReason
    }
}
