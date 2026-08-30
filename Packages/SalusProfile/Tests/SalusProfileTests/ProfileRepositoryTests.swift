// The twin of what Android covers with Turbine over `ProfileRepositoryImpl`'s `Flow`, run against
// a real migrated database (`SalusDatabase.inMemory`) rather than a mock DAO — the `created_at`
// preservation in `ProfileRepositoryImpl.kt:21-26` is a fact about the stored row, and only a real
// row can prove it.
//
// Deterministic by construction: the clock is a `FixedSalusClock` and the observation is read by
// awaiting stream values, never by sleeping.

import Foundation
import SalusDatabase
import SalusModel
import SalusTesting
import Testing

@testable import SalusProfile

@Suite("ProfileRepository")
struct ProfileRepositoryTests {
    /// The instant the database is seeded at, and the one a first save is stamped with.
    private static let seededAt = Date(timeIntervalSince1970: 1_700_000_000)
    private static let seededAtEpochMs: Int64 = 1_700_000_000_000
    /// Deliberately later than `seededAt`, so a re-save that re-stamped would be visible.
    private static let laterInstant = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("observeProfile emits the seeded default profile first")
    func observeProfileEmitsTheSeededDefaultProfileFirst() async throws {
        let fixture = try Self.makeFixture()

        var iterator = fixture.repository.observeProfile().makeAsyncIterator()
        let profile = try #require(try await iterator.next())

        #expect(profile?.id == SalusDatabase.defaultProfileId)
        #expect(profile?.isDefault == true)
        // `SeedDefaultProfileCallback` writes an empty name; onboarding fills it in.
        #expect(profile?.displayName.isEmpty == true)
    }

    /// `ProfileRepositoryImpl.kt:23-24`, the `?:` branch: a row nothing wrote before gets "now".
    @Test("saveProfile stamps created_at from the clock for a row that is not there yet")
    func saveProfileStampsCreatedAtFromTheClock() async throws {
        let fixture = try Self.makeFixture()

        try await fixture.repository.saveProfile(Self.newProfile(displayName: "Ada"))

        let record = try #require(try await fixture.dao.getById("p1"))
        #expect(record.createdAtEpochMs == Self.seededAtEpochMs)
    }

    /// `ProfileRepositoryImpl.kt:23`, the `getById` branch: an existing row keeps its own
    /// `created_at` however far the clock has moved on.
    @Test("saveProfile preserves created_at on a re-save and updates the other fields")
    func saveProfilePreservesCreatedAtOnAResave() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveProfile(Self.newProfile(displayName: "Ada"))

        fixture.clock.advanceTo(Self.laterInstant)
        try await fixture.repository.saveProfile(
            Self.newProfile(displayName: "Ada Lovelace", healthNotes: "Pollen allergy")
        )

        let record = try #require(try await fixture.dao.getById("p1"))
        #expect(record.createdAtEpochMs == Self.seededAtEpochMs)
        #expect(record.displayName == "Ada Lovelace")
        #expect(record.healthNotes == "Pollen allergy")
    }

    @Test("getProfile reads back what saveProfile wrote")
    func getProfileReadsBackWhatSaveProfileWrote() async throws {
        let fixture = try Self.makeFixture()
        let saved = Profile(
            id: SalusDatabase.defaultProfileId,
            displayName: "Ada",
            birthDate: LocalDate(year: 1990, month: 6, day: 15),
            sex: .female,
            heightCm: 168.0,
            healthNotes: "Pollen allergy",
            isDefault: true
        )

        try await fixture.repository.saveProfile(saved)

        #expect(try await fixture.repository.getProfile() == saved)
    }

    /// The twin of Koin resolving `single<ProfileRepository>` (`ProfileModule.kt:7-9`): what the
    /// factory hands back is a working repository over the given database, not just a value.
    @Test("makeProfileRepository builds a repository over the given database")
    func makeProfileRepositoryBuildsAWorkingRepository() async throws {
        let clock = FixedSalusClock(now: Self.seededAt)
        let database = try SalusDatabase.inMemory(clock: clock)
        let repository = makeProfileRepository(database: database, clock: clock)

        var iterator = repository.observeProfile().makeAsyncIterator()
        let profile = try #require(try await iterator.next())

        #expect(profile?.id == SalusDatabase.defaultProfileId)
        #expect(profile?.isDefault == true)
    }

    /// A profile whose id is not in the seeded database, so `getById` misses and the clock decides
    /// the stamp. It is not the default one — "the default profile" has to stay the seeded row.
    private static func newProfile(displayName: String, healthNotes: String? = nil) -> Profile {
        Profile(
            id: "p1",
            displayName: displayName,
            birthDate: nil,
            sex: nil,
            heightCm: nil,
            healthNotes: healthNotes,
            isDefault: false
        )
    }

    private static func makeFixture() throws -> (
        repository: ProfileRepositoryImpl,
        dao: ProfileDao,
        clock: FixedSalusClock
    ) {
        let clock = FixedSalusClock(now: seededAt)
        let dao = try ProfileDao(database: SalusDatabase.inMemory(clock: clock))
        return (ProfileRepositoryImpl(profileDao: dao, clock: clock), dao, clock)
    }
}

/// The companion constant `:feature:settings` and `:feature:onboarding` reach for
/// (`ProfileRepository.kt:25-28`). It is the id the migration seeds, so it is pinned against the
/// database's own constant rather than re-spelled.
@Suite("ProfileRepositoryDefaults")
struct ProfileRepositoryDefaultsTests {
    @Test("the repository's default profile id is the database's")
    func defaultProfileIdMirrorsTheDatabase() {
        #expect(ProfileRepositoryDefaults.defaultProfileId == SalusDatabase.defaultProfileId)
    }
}
