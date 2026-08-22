// Ported 1:1 from
// `core/profile/src/main/kotlin/com/alicansekban/salus/core/profile/ProfileMappers.kt`.
//
// The Kotlin functions are `internal`; so are these, which is the same reach — a Swift module is
// the unit Gradle calls a module. `ProfileMappersTests` uses `@testable import`, the twin of
// Kotlin test sources seeing their module's internals.

import SalusDatabase
import SalusModel

/// Database records never leak past this file. Birth dates are stored as epoch days (the
/// project-wide representation for calendar days) and sex as the enum's raw value, resolved by
/// lookup so a value written by a future version degrades to nil instead of throwing.
///
/// `ProfileMappers.kt:13-21`.
extension ProfileRecord {
    func toDomain() -> Profile {
        Profile(
            id: id,
            displayName: displayName,
            birthDate: birthDateEpochDay.map { LocalDate(epochDay: $0) },
            // The twin of `Sex.entries.firstOrNull { it.name == stored }`: raw values are the
            // Kotlin constant names, so the failable initializer is the same lookup.
            sex: sex.flatMap { Sex(rawValue: $0) },
            heightCm: heightCm,
            healthNotes: healthNotes,
            isDefault: isDefault
        )
    }
}

/// `ProfileMappers.kt:23-32`.
extension Profile {
    func toRecord(createdAtEpochMs: Int64) -> ProfileRecord {
        ProfileRecord(
            id: id,
            displayName: displayName,
            birthDateEpochDay: birthDate?.epochDay,
            sex: sex?.rawValue,
            heightCm: heightCm,
            healthNotes: healthNotes,
            isDefault: isDefault,
            createdAtEpochMs: createdAtEpochMs
        )
    }
}
