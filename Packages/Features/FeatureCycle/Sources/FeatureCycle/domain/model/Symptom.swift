// Ported 1:1 from Android
// `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/domain/model/Symptom.kt`.

/// Catalog symptom. ``nameKey`` is a stable string-resource key (e.g. `"cramps"`), not display
/// text — the UI resolves it to a localized label (`Symptom.kt:7-12`).
public struct Symptom: Equatable, Hashable, Sendable {
    public let id: String
    public let nameKey: String
    public let isCustom: Bool
    public let iconToken: String?

    public init(id: String, nameKey: String, isCustom: Bool, iconToken: String?) {
        self.id = id
        self.nameKey = nameKey
        self.isCustom = isCustom
        self.iconToken = iconToken
    }
}
