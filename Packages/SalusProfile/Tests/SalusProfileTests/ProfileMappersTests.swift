// Ported 1:1 from
// `core/profile/src/test/kotlin/com/alicansekban/salus/core/profile/ProfileMappersTest.kt`.
//
// The five case names are the Kotlin ones verbatim, so a drift on either platform is visible by
// name. "Entity" in those names is Room's `ProfileEntity`; its twin here is `ProfileRecord`.
//
// `assertEquals(expected, actual, 0.001)` becomes an explicit delta comparison rather than `==`:
// the Kotlin assertion is what is being ported, and the tolerance is part of it.

import Foundation
import SalusDatabase
import SalusModel
import Testing

@testable import SalusProfile

@Suite("ProfileMappers")
struct ProfileMappersTests {
    /// `ProfileMappersTest.kt:13-25`.
    @Test("entity maps to domain with epoch day converted to a local date")
    func entityMapsToDomainWithEpochDayConvertedToALocalDate() throws {
        let record = Self.record(birthDateEpochDay: 0, sex: "FEMALE", heightCm: 168.0)

        let profile = record.toDomain()

        #expect(profile.id == "p1")
        #expect(profile.displayName == "Ada")
        #expect(profile.birthDate == LocalDate(year: 1970, month: 1, day: 1))
        #expect(profile.sex == .female)
        let heightCm = try #require(profile.heightCm)
        #expect(abs(heightCm - 168.0) < 0.001)
        #expect(profile.isDefault == true)
    }

    /// `ProfileMappersTest.kt:27-34`.
    @Test("null optional columns map to null domain fields")
    func nullOptionalColumnsMapToNullDomainFields() {
        let profile = Self.record().toDomain()

        #expect(profile.birthDate == nil)
        #expect(profile.sex == nil)
        #expect(profile.heightCm == nil)
    }

    /// `ProfileMappersTest.kt:36-39` — a value written by a future version degrades to nil.
    @Test("an unknown sex string maps to null rather than throwing")
    func anUnknownSexStringMapsToNullRatherThanThrowing() {
        #expect(Self.record(sex: "NOT_A_SEX").toDomain().sex == nil)
    }

    /// `ProfileMappersTest.kt:41-60`.
    @Test("domain maps back to entity preserving the creation timestamp")
    func domainMapsBackToEntityPreservingTheCreationTimestamp() throws {
        let profile = Profile(
            id: "p1",
            displayName: "Ada",
            birthDate: LocalDate(year: 1990, month: 6, day: 15),
            sex: .other,
            heightCm: 170.5,
            healthNotes: "Pollen allergy",
            isDefault: true
        )

        let record = profile.toRecord(createdAtEpochMs: 42)

        #expect(record.birthDateEpochDay == LocalDate(year: 1990, month: 6, day: 15).epochDay)
        #expect(record.sex == "OTHER")
        let heightCm = try #require(record.heightCm)
        #expect(abs(heightCm - 170.5) < 0.001)
        #expect(record.healthNotes == "Pollen allergy")
        #expect(record.createdAtEpochMs == 42)
    }

    /// `ProfileMappersTest.kt:62-75`.
    @Test("round trip through the entity preserves every field")
    func roundTripThroughTheEntityPreservesEveryField() {
        let original = Profile(
            id: "p1",
            displayName: "Ada",
            birthDate: LocalDate(year: 1990, month: 6, day: 15),
            sex: .male,
            heightCm: 180.0,
            healthNotes: nil,
            isDefault: true
        )

        #expect(original.toRecord(createdAtEpochMs: 7).toDomain() == original)
    }

    /// The twin of the Kotlin `entity(...)` helper (`ProfileMappersTest.kt:77-91`).
    private static func record(
        birthDateEpochDay: Int? = nil,
        sex: String? = nil,
        heightCm: Double? = nil,
        healthNotes: String? = nil
    ) -> ProfileRecord {
        ProfileRecord(
            id: "p1",
            displayName: "Ada",
            birthDateEpochDay: birthDateEpochDay,
            sex: sex,
            heightCm: heightCm,
            healthNotes: healthNotes,
            isDefault: true,
            createdAtEpochMs: 1_700_000_000_000
        )
    }
}
