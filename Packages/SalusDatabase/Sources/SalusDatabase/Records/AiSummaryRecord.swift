// Ported 1:1 from `core/database/.../entity/AiSummaryEntity.kt`.
// Conventions: see `ProfileRecord`.

import GRDB

/// A generated health summary, cached so re-opening the same period does not spend another AI
/// call (`AiSummaryEntity.kt:6-19`).
///
/// No `id`: the key is `(period_type, start_epoch_day, language)`. The same week asked for in
/// Turkish and in English are two different summaries, while re-generating the same week in the
/// same language replaces the row. `endEpochDay` is data, not identity — it is derivable from the
/// period type and start. Not tied to a profile: the cache is dropped rather than migrated when
/// multi-profile lands.
public struct AiSummaryRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "ai_summaries"

    public let periodType: String
    public let startEpochDay: Int
    public let endEpochDay: Int
    /// BCP-47 language tag the summary text is written in, e.g. `"tr"` or `"en"`.
    public let language: String
    public let text: String
    public let createdAtEpochMs: Int64

    enum CodingKeys: String, CodingKey {
        case periodType = "period_type"
        case startEpochDay = "start_epoch_day"
        case endEpochDay = "end_epoch_day"
        case language
        case text
        case createdAtEpochMs = "created_at_epoch_ms"
    }

    public init(
        periodType: String,
        startEpochDay: Int,
        endEpochDay: Int,
        language: String,
        text: String,
        createdAtEpochMs: Int64
    ) {
        self.periodType = periodType
        self.startEpochDay = startEpochDay
        self.endEpochDay = endEpochDay
        self.language = language
        self.text = text
        self.createdAtEpochMs = createdAtEpochMs
    }
}
