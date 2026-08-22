// Ported 1:1 from Android
// `core/model/src/main/kotlin/com/alicansekban/salus/core/model/Profile.kt`.
//
// Kotlin's `birthDate` is a `kotlinx.datetime.LocalDate`. Swift has no such type in the standard
// library and this package links no framework, so it is `LocalDate` from `LocalDate.swift` —
// the same calendar, the same epoch-day arithmetic.

/// One person the app keeps records for. The Kotlin data class is `Profile.kt:5-14`.
public struct Profile: Equatable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let birthDate: LocalDate?
    public let sex: Sex?
    public let heightCm: Double?
    /// Free text the user gave at onboarding: chronic conditions, allergies.
    public let healthNotes: String?
    public let isDefault: Bool

    public init(
        id: String,
        displayName: String,
        birthDate: LocalDate?,
        sex: Sex?,
        heightCm: Double?,
        healthNotes: String?,
        isDefault: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.birthDate = birthDate
        self.sex = sex
        self.heightCm = heightCm
        self.healthNotes = healthNotes
        self.isDefault = isDefault
    }
}

/// Raw values are the Kotlin constant names (`Profile.kt:16-20`), which is what is persisted.
public enum Sex: String, CaseIterable, Equatable, Hashable, Sendable {
    case female = "FEMALE"
    case male = "MALE"
    case other = "OTHER"
}
