// Ported from the `vitals range query emits inserted measurements in order` case of
// `core/database/src/test/kotlin/com/alicansekban/salus/core/database/DaoSmokeTest.kt:120-131`,
// plus the boundary and observation halves Android leaves to Turbine and to the SQL itself.
//
// As in `ProfileDaoTests`, the fixture is `SalusDatabase.inMemory`, which runs the migrations —
// so the seeded default profile is already there and the Kotlin `p1` profile is a second row.

import Foundation
import GRDB
import SalusTesting
import Testing

@testable import SalusDatabase

@Suite("VitalsDao")
struct VitalsDaoTests {
    private let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_700_000_000))

    /// `DaoSmokeTest.kt:120-131`, verbatim: the rows go in newest-first and come back oldest-first,
    /// because the query orders by `measured_at_epoch_ms ASC`, not by insertion.
    @Test("vitals range query emits inserted measurements in order")
    func vitalsRangeQueryEmitsInsertedMeasurementsInOrder() async throws {
        let dao = try await makeDao()
        try await dao.upsert(Self.weight(id: "w1", measuredAt: 2000))
        try await dao.upsert(Self.weight(id: "w2", measuredAt: 1000))

        var iterator = dao.observeRange(
            profileId: "p1",
            type: "WEIGHT",
            fromEpochMs: 0,
            untilEpochMs: 10000
        ).makeAsyncIterator()

        let items = try #require(try await iterator.next())
        #expect(items.map(\.id) == ["w2", "w1"])
    }

    /// `VitalsDao.kt:22` — `BETWEEN` is inclusive at both ends, so a measurement taken exactly on
    /// either bound is in the window and one a millisecond outside it is not.
    @Test("observeRange includes both bounds and excludes the milliseconds beyond them")
    func observeRangeIncludesBothBounds() async throws {
        let dao = try await makeDao()
        try await dao.upsert(Self.weight(id: "before", measuredAt: 999))
        try await dao.upsert(Self.weight(id: "from", measuredAt: 1000))
        try await dao.upsert(Self.weight(id: "until", measuredAt: 2000))
        try await dao.upsert(Self.weight(id: "after", measuredAt: 2001))

        var iterator = dao.observeRange(
            profileId: "p1",
            type: "WEIGHT",
            fromEpochMs: 1000,
            untilEpochMs: 2000
        ).makeAsyncIterator()

        let items = try #require(try await iterator.next())
        #expect(items.map(\.id) == ["from", "until"])
    }

    /// `VitalsDao.kt:21` — the other profile's and the other type's rows are not in the window
    /// either, however well their timestamps fit.
    @Test("observeRange answers for one profile and one type only")
    func observeRangeFiltersByProfileAndType() async throws {
        let dao = try await makeDao()
        try await dao.upsert(Self.weight(id: "mine", measuredAt: 1000))
        try await dao.upsert(Self.weight(
            id: "other-profile",
            measuredAt: 1000,
            profileId: SalusDatabase.defaultProfileId
        ))
        try await dao.upsert(Self.weight(id: "other-type", measuredAt: 1000, type: "BLOOD_GLUCOSE"))

        var iterator = dao.observeRange(
            profileId: "p1",
            type: "WEIGHT",
            fromEpochMs: 0,
            untilEpochMs: 10000
        ).makeAsyncIterator()

        let items = try #require(try await iterator.next())
        #expect(items.map(\.id) == ["mine"])
    }

    /// The twin of Android's Turbine test over `Flow<VitalsMeasurementEntity?>`
    /// (`VitalsDao.kt:33-41`): the newest row first, then a fresh one after an insert that
    /// supersedes it.
    @Test("observeLatest emits the newest row and again after an insert")
    func observeLatestEmitsOnInsert() async throws {
        let dao = try await makeDao()
        try await dao.upsert(Self.weight(id: "old", measuredAt: 1000))

        var iterator = dao.observeLatest(profileId: "p1", type: "WEIGHT").makeAsyncIterator()

        let first = try #require(try await iterator.next())
        #expect(first?.id == "old")

        try await dao.upsert(Self.weight(id: "new", measuredAt: 2000))

        let updated = try #require(try await iterator.next())
        #expect(updated?.id == "new")
    }

    /// `ORDER BY measured_at_epoch_ms DESC LIMIT 1` on an empty table is no row, not an empty list.
    @Test("observeLatest emits nil when the profile has no measurement of that type")
    func observeLatestEmitsNilWhenEmpty() async throws {
        let dao = try await makeDao()
        try await dao.upsert(Self.weight(id: "w1", measuredAt: 1000))

        var iterator = dao.observeLatest(profileId: "p1", type: "BLOOD_PRESSURE").makeAsyncIterator()

        let first = try #require(try await iterator.next())
        #expect(first == nil)
    }

    /// `VitalsDao.kt:45-57` — the same window, every type at once, still ordered by the timestamp.
    @Test("getMeasurementsBetween returns every type in one ordered list")
    func getMeasurementsBetweenReturnsEveryType() async throws {
        let dao = try await makeDao()
        try await dao.upsert(Self.weight(id: "glucose", measuredAt: 2000, type: "BLOOD_GLUCOSE"))
        try await dao.upsert(Self.weight(id: "weight", measuredAt: 1000))
        try await dao.upsert(Self.weight(id: "after", measuredAt: 2001))
        try await dao.upsert(Self.weight(
            id: "other-profile",
            measuredAt: 1500,
            profileId: SalusDatabase.defaultProfileId
        ))

        let measurements = try await dao.getMeasurementsBetween(
            profileId: "p1",
            fromEpochMs: 1000,
            untilEpochMs: 2000
        )

        #expect(measurements.map(\.id) == ["weight", "glucose"])
    }

    /// `VitalsDao.kt:15-16` and `:59-60`.
    @Test("getById reads the row back, deleteById removes it")
    func getByIdAndDeleteById() async throws {
        let dao = try await makeDao()
        let measurement = Self.weight(id: "w1", measuredAt: 1000)
        try await dao.upsert(measurement)

        #expect(try await dao.getById("w1") == measurement)

        try await dao.deleteById("w1")

        #expect(try await dao.getById("w1") == nil)
    }

    @Test("getById answers nil for an id that is not there")
    func getByIdAnswersNilForAnUnknownId() async throws {
        let dao = try await makeDao()

        #expect(try await dao.getById("nope") == nil)
    }

    /// `@Upsert` (`VitalsDao.kt:12-13`) replaces the row that shares the primary key rather than
    /// adding a second one.
    @Test("upsert replaces the row that shares the id")
    func upsertReplacesTheRowThatSharesTheId() async throws {
        let dao = try await makeDao()
        try await dao.upsert(Self.weight(id: "w1", measuredAt: 1000))

        try await dao.upsert(Self.weight(id: "w1", measuredAt: 3000))

        #expect(try await dao.getById("w1")?.measuredAtEpochMs == 3000)
        let all = try await dao.getMeasurementsBetween(profileId: "p1", fromEpochMs: 0, untilEpochMs: 10000)
        #expect(all.count == 1)
    }

    /// The Kotlin fixture's `p1` profile (`DaoSmokeTest.kt:34-43`), which every measurement below
    /// hangs off — `vitals_measurements.profile_id` is a cascading foreign key.
    private func makeDao() async throws -> VitalsDao {
        let database = try SalusDatabase.inMemory(clock: clock)
        try await ProfileDao(database: database).upsert(Self.profile)
        return VitalsDao(database: database)
    }

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

    /// `DaoSmokeTest.kt:199-211`, with the profile and the type opened up so the filtering tests
    /// can write a row the query is supposed to skip.
    private static func weight(
        id: String,
        measuredAt: Int64,
        profileId: String = "p1",
        type: String = "WEIGHT"
    ) -> VitalsMeasurementRecord {
        VitalsMeasurementRecord(
            id: id,
            profileId: profileId,
            type: type,
            measuredAtEpochMs: measuredAt,
            timeZoneId: "Europe/Istanbul",
            valuePrimary: 80.0,
            valueSecondary: nil,
            valueTertiary: nil,
            unit: "kg",
            measurementContext: nil,
            note: nil
        )
    }
}
