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

        let first = try #require(try await iterator.next())
        #expect(first?.id == SalusDatabase.defaultProfileId)
        #expect(first?.displayName.isEmpty == true)

        let seeded = try #require(first)
        try await dao.upsert(seeded.with(displayName: "Ada", healthNotes: nil))

        // The buffering policy keeps only the newest value, so what arrives next is the current
        // row — a queue of superseded ones is what `.unbounded` would have handed over.
        let updated = try #require(try await iterator.next())
        #expect(updated?.displayName == "Ada")
        #expect(updated?.id == SalusDatabase.defaultProfileId)
    }

    /// The reason the stream throws. Kotlin's `Flow` propagates a failing query to the collector;
    /// this proves the port does too, against a real unreadable database rather than a stub.
    ///
    /// The failure is provoked on the observation's *first* fetch, by dropping the table before
    /// anyone subscribes. Breaking a *live* observation instead does not work and is worth
    /// recording: SQLite's update hook — which is what GRDB's invalidation is built on — does not
    /// fire for DDL, so a `DROP TABLE` under a running observation produces no new fetch at all
    /// and the consumer simply waits forever. A first-fetch failure exercises the same path the
    /// production error would take: `AsyncValueObservation` throws, and the `catch` finishes the
    /// stream `throwing:` rather than swallowing it.
    @Test("observeDefaultProfile surfaces an observation failure to the consumer")
    func observeDefaultProfileSurfacesAFailure() async throws {
        let database = try SalusDatabase.inMemory(clock: clock)
        let dao = ProfileDao(database: database)

        try await database.writer.write { db in
            // The children's foreign keys would otherwise refuse the drop.
            try db.execute(sql: "PRAGMA foreign_keys = OFF")
            try db.execute(sql: "DROP TABLE profiles")
        }

        var iterator = dao.observeDefaultProfile().makeAsyncIterator()

        let error = await #expect(throws: DatabaseError.self) {
            try await iterator.next()
        }
        #expect(error?.resultCode == .SQLITE_ERROR)
        #expect(error?.message?.contains("no such table: profiles") == true)
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
