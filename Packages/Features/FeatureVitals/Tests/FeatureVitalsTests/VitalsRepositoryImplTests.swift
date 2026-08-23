// Covers `data/VitalsRepositoryImpl.swift`, the port of
// `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/data/VitalsRepositoryImpl.kt`.
//
// No Android twin is needed: Android reaches the same statements through `DaoSmokeTest`, which
// exercises `VitalsDao` against an in-memory Room database. This does the same thing one layer up,
// against `SalusDatabase.inMemory`, because the facts worth proving here — that a saved entry
// comes back as a `WEIGHT` row, that `getWeightEntry` refuses a row of another type
// (`VitalsRepositoryImpl.kt:36`), that the observations are closed at both ends and re-emit after
// a write — are facts about real SQL, and a mocked DAO would only prove the mock.
//
// Deterministic by construction: a `FixedSalusClock`, and every observation read by awaiting a
// stream value rather than by sleeping.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel
import SalusTesting
import Testing

@testable import FeatureVitals

@Suite("VitalsRepositoryImpl")
struct VitalsRepositoryImplTests {
    private static let seededAt = Date(timeIntervalSince1970: 1_700_000_000)
    private static let zone = FixedSalusClock.defaultZone

    /// `VitalsRepositoryImpl.kt:38-40` — the write goes through `WeightEntry.toRecord`, so the row
    /// carries the discriminator and the unit the other platform reads back.
    @Test("saveWeightEntry writes a WEIGHT row for the given profile")
    func saveWeightEntryWritesAWeightRow() async throws {
        let fixture = try Self.makeFixture()

        try await fixture.repository.saveWeightEntry(Self.entry(id: "w1", kilograms: 82.5))

        let record = try #require(try await fixture.dao.getById("w1"))
        #expect(record.type == VitalType.weight.rawValue)
        #expect(record.unit == "kg")
        #expect(record.profileId == SalusDatabase.defaultProfileId)
        #expect(record.valuePrimary == 82.5)
    }

    /// `VitalsRepositoryImpl.kt:35-36` and `:38-40` together: what was written is what is read.
    @Test("getWeightEntry reads back what saveWeightEntry wrote")
    func getWeightEntryReadsBackWhatSaveWrote() async throws {
        let fixture = try Self.makeFixture()
        let entry = Self.entry(id: "w1", kilograms: 82.5, note: "after breakfast")

        try await fixture.repository.saveWeightEntry(entry)

        #expect(try await fixture.repository.getWeightEntry(id: "w1") == entry)
    }

    /// `VitalsRepositoryImpl.kt:36` — the `takeIf { it.type == WEIGHT }` guard. The three vital
    /// types share one table, so without it a blood-pressure row would be handed back as a weight
    /// whose kilograms are actually a systolic reading.
    @Test("getWeightEntry ignores a row of another type")
    func getWeightEntryIgnoresARowOfAnotherType() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.dao.upsert(
            VitalsMeasurementRecord(
                id: "bp1",
                profileId: SalusDatabase.defaultProfileId,
                type: VitalType.bloodPressure.rawValue,
                measuredAtEpochMs: Self.seededAt.epochMilliseconds,
                timeZoneId: Self.zone.identifier,
                valuePrimary: 120,
                valueSecondary: 80,
                valueTertiary: nil,
                unit: "mmHg",
                measurementContext: nil,
                note: nil
            )
        )

        #expect(try await fixture.repository.getWeightEntry(id: "bp1") == nil)
    }

    /// The mapper throws on a stored zone id this platform cannot resolve
    /// (`WeightEntryMapper.kt:16`), and a Kotlin `Flow.map` whose lambda throws fails its
    /// collector. The Swift stream has to do the same rather than end quietly, or a corrupt row
    /// would show up as an empty history list.
    @Test("an unresolvable stored time zone id fails the history stream")
    func anUnresolvableStoredTimeZoneIdFailsTheStream() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.dao.upsert(
            VitalsMeasurementRecord(
                id: "w1",
                profileId: SalusDatabase.defaultProfileId,
                type: VitalType.weight.rawValue,
                measuredAtEpochMs: Self.seededAt.epochMilliseconds,
                timeZoneId: "Mars/Olympus_Mons",
                valuePrimary: 82.5,
                valueSecondary: nil,
                valueTertiary: nil,
                unit: "kg",
                measurementContext: nil,
                note: nil
            )
        )

        var iterator = fixture.repository
            .observeWeightHistory(from: Self.seededAt, until: Self.seededAt.addingTimeInterval(60))
            .makeAsyncIterator()

        await #expect(throws: IllegalTimeZoneError.unknownTimeZone("Mars/Olympus_Mons")) {
            try await iterator.next()
        }
    }

    /// `VitalsRepositoryImpl.kt:20-28` — oldest first, and the window is closed at both ends
    /// because the DAO's `BETWEEN` is.
    @Test("observeWeightHistory emits the window's rows, oldest first, both ends included")
    func observeWeightHistoryEmitsTheWindowsRowsOldestFirst() async throws {
        let fixture = try Self.makeFixture()
        let from = Self.seededAt
        let until = Self.seededAt.addingTimeInterval(200)
        try await fixture.repository.saveWeightEntry(Self.entry(id: "before", at: from.addingTimeInterval(-1)))
        try await fixture.repository.saveWeightEntry(Self.entry(id: "last", at: until))
        try await fixture.repository.saveWeightEntry(Self.entry(id: "first", at: from))
        try await fixture.repository.saveWeightEntry(Self.entry(id: "after", at: until.addingTimeInterval(1)))

        var iterator = fixture.repository.observeWeightHistory(from: from, until: until).makeAsyncIterator()
        let history = try #require(try await iterator.next())

        #expect(history.map(\.id) == ["first", "last"])
    }

    /// A GRDB observation re-runs its query when the table changes, which is what Room's `Flow`
    /// does and what the history screen depends on.
    @Test("observeWeightHistory re-emits after a save")
    func observeWeightHistoryReEmitsAfterASave() async throws {
        let fixture = try Self.makeFixture()
        let from = Self.seededAt
        let until = Self.seededAt.addingTimeInterval(200)

        var iterator = fixture.repository.observeWeightHistory(from: from, until: until).makeAsyncIterator()
        #expect(try await iterator.next()?.isEmpty == true)

        try await fixture.repository.saveWeightEntry(Self.entry(id: "w1", at: from))

        let history = try #require(try await iterator.next())
        #expect(history.map(\.id) == ["w1"])
    }

    /// `VitalsRepositoryImpl.kt:30-33` — the newest row of this type, whenever it was written.
    @Test("observeLatestWeight emits the newest entry")
    func observeLatestWeightEmitsTheNewestEntry() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveWeightEntry(Self.entry(id: "older", at: Self.seededAt))
        try await fixture.repository.saveWeightEntry(
            Self.entry(id: "newer", kilograms: 81.0, at: Self.seededAt.addingTimeInterval(60))
        )

        var iterator = fixture.repository.observeLatestWeight().makeAsyncIterator()
        let latest = try #require(try await iterator.next())

        #expect(latest?.id == "newer")
        #expect(latest?.kilograms == 81.0)
    }

    /// `VitalsRepositoryImpl.kt:42-44`.
    @Test("deleteWeightEntry removes the row")
    func deleteWeightEntryRemovesTheRow() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveWeightEntry(Self.entry(id: "w1"))

        try await fixture.repository.deleteWeightEntry(id: "w1")

        #expect(try await fixture.repository.getWeightEntry(id: "w1") == nil)
    }

    /// A second save of the same id updates rather than duplicating — the DAO's `upsert`
    /// (`VitalsRepositoryImpl.kt:39`), which is what an edit in the weight editor relies on.
    @Test("saving the same id twice updates the row instead of adding one")
    func savingTheSameIdTwiceUpdatesTheRow() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.saveWeightEntry(Self.entry(id: "w1", kilograms: 80.0))

        try await fixture.repository.saveWeightEntry(Self.entry(id: "w1", kilograms: 81.0))

        let stored = try #require(try await fixture.repository.getWeightEntry(id: "w1"))
        #expect(stored.kilograms == 81.0)
        let window = try await fixture.dao.getMeasurementsBetween(
            profileId: SalusDatabase.defaultProfileId,
            fromEpochMs: 0,
            untilEpochMs: Int64.max
        )
        #expect(window.count == 1)
    }

    private static func entry(
        id: String,
        kilograms: Double = 82.5,
        at instant: Date = seededAt,
        note: String? = nil
    ) -> WeightEntry {
        WeightEntry(id: id, measuredAt: instant, timeZone: zone, kilograms: kilograms, note: note)
    }

    private static func makeFixture() throws -> (repository: VitalsRepositoryImpl, dao: VitalsDao) {
        let clock = FixedSalusClock(now: seededAt)
        let dao = try VitalsDao(database: SalusDatabase.inMemory(clock: clock))
        return (VitalsRepositoryImpl(vitalsDao: dao), dao)
    }
}
