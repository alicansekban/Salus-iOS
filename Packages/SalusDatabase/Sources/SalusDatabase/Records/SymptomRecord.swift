// Ported 1:1 from `core/database/.../entity/CycleEntity.kt` (the `SymptomEntity` part).
// Conventions: see `ProfileRecord`.

import GRDB

/// The seeded symptom catalog. `nameKey` is a string resource key, not display text
/// (`CycleEntity.kt:53`) — which is what lets the same row read Turkish or English.
public struct SymptomRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "symptoms"

    public let id: String
    public let nameKey: String
    public let isCustom: Bool
    public let iconToken: String?

    enum CodingKeys: String, CodingKey {
        case id
        case nameKey = "name_key"
        case isCustom = "is_custom"
        case iconToken = "icon_token"
    }

    public init(id: String, nameKey: String, isCustom: Bool, iconToken: String?) {
        self.id = id
        self.nameKey = nameKey
        self.isCustom = isCustom
        self.iconToken = iconToken
    }
}
