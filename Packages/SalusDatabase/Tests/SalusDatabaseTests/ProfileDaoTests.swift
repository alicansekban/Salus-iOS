// Ported from the `profile upsert and read back` case of
// `core/database/src/test/kotlin/com/alicansekban/salus/core/database/DaoSmokeTest.kt:58-67`,
// plus the observation half that Android covers with Turbine.
//
// The Kotlin fixture builds an empty in-memory database. This one comes out of
// `SalusDatabase.inMemory`, which runs the migrations — so the seeded default profile is already
// there, and the counts below say 2 where Kotlin's say 1. That is the port being honest about a
// real difference: on Android the seed lives in a `RoomDatabase.Callback` that
// `inMemoryDatabaseBuilder` never registers, so its smoke test never sees it.

import Foundation
import GRDB
import SalusTesting
import Testing

@testable import SalusDatabase

@Suite("ProfileDao")
struct ProfileDaoTests {
    private let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_700_000_000))

    /// `DaoSmokeTest.kt:58-67`.
    @Test("profile upsert and read back")
    func profileUpsertAndReadBack() async throws {
        let dao = try makeDao()

        try await dao.upsert(Self.profile)

        let loaded = try await dao.getById("p1")
        #expect(loaded == Self.profile)
        // The seeded default profile plus the one just written.
        #expect(try await dao.count() == 2)
    }

    @Test("upsert replaces the row that shares the id")
    func upsertReplacesTheRowThatSharesTheId() async throws {
        let dao = try makeDao()
        try await dao.upsert(Self.profile)

        try await dao.upsert(Self.profile.with(displayName: "Ada", healthNotes: "Penisilin alerjisi"))

        let loaded = try await dao.getById("p1")
        #expect(loaded?.displayName == "Ada")
        #expect(loaded?.healthNotes == "Penisilin alerjisi")
        #expect(try await dao.count() == 2)
    }

    @Test("getById answers nil for an id that is not there")
    func getByIdAnswersNilForAnUnknownId() async throws {
        let dao = try makeDao()

        #expect(try await dao.getById("nope") == nil)
    }

    /// `ProfileDao.kt:19-20` — "the default profile" is the first row with `is_default = 1`, not
    /// the row whose id is `defaultProfileId`. The two agree today; the query is what defines it.
    @Test("getDefaultProfile reads the seeded row, not the newest one")
    func getDefaultProfileReadsTheSeededRow() async throws {
        let dao = try makeDao()
        try await dao.upsert(Self.profile)

        let loaded = try await dao.getDefaultProfile()

        #expect(loaded?.id == SalusDatabase.defaultProfileId)
        #expect(loaded?.isDefault == true)
        #expect(loaded?.createdAtEpochMs == 1_700_000_000_000)
    }

    /// The twin of Android's Turbine test over `Flow<ProfileEntity?>`: the current value first,
    /// then a fresh one after a write that changes the row.
    @Test("observeDefaultProfile emits the current row and again after an update")
    func observeDefaultProfileEmitsOnUpdate() async throws {
        let database = try SalusDatabase.inMemory(clock: clock)
        let dao = ProfileDao(database: database)

        var iterator = dao.observeDefaultProfile().makeAsyncIterator()

        let first = try #require(await iterator.next())
        #expect(first?.id == SalusDatabase.defaultProfileId)
        #expect(first?.displayName.isEmpty == true)

        let seeded = try #require(first)
        try await dao.upsert(seeded.with(displayName: "Ada", healthNotes: nil))

        // `ValueObservation` coalesces, so the next value is the latest — never a stale one.
        let updated = try #require(await iterator.next())
        #expect(updated?.displayName == "Ada")
        #expect(updated?.id == SalusDatabase.defaultProfileId)
    }

    private func makeDao() throws -> ProfileDao {
        try ProfileDao(database: SalusDatabase.inMemory(clock: clock))
    }

    /// `DaoSmokeTest.kt:35-44`, verbatim.
    private static let profile = ProfileRecord(
        id: "p1",
        displayName: "Test",
        birthDateEpochDay: nil,
        sex: nil,
        heightCm: nil,
        healthNotes: nil,
        isDefault: true,
        createdAtEpochMs: 0
    )
}

extension ProfileRecord {
    /// The records are immutable, the way the Kotlin `data class`es they port are. This is the
    /// `copy()` the two edit tests above need, and no more of it than they need.
    fileprivate func with(displayName: String, healthNotes: String?) -> ProfileRecord {
        ProfileRecord(
            id: id,
            displayName: displayName,
            birthDateEpochDay: birthDateEpochDay,
            sex: sex,
            heightCm: heightCm,
            healthNotes: healthNotes,
            isDefault: isDefault,
            createdAtEpochMs: createdAtEpochMs
        )
    }
}
