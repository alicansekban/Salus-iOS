// Ported 1:1 from `core/database/.../entity/CycleEntity.kt` (the `CycleEntrySymptomEntity` part).
// Conventions: see `ProfileRecord`.

import GRDB

/// The join row between a daily entry and a symptom, carrying its severity.
///
/// No `id`: the primary key is `(entry_id, symptom_id)`, so the pair is the identity — the same
/// symptom cannot be recorded twice for one day. Cascade-deleted with either side.
public struct CycleEntrySymptomRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "cycle_entry_symptoms"

    public let entryId: String
    public let symptomId: String
    public let severity: Int

    enum CodingKeys: String, CodingKey {
        case entryId = "entry_id"
        case symptomId = "symptom_id"
        case severity
    }

    public init(entryId: String, symptomId: String, severity: Int) {
        self.entryId = entryId
        self.symptomId = symptomId
        self.severity = severity
    }
}
