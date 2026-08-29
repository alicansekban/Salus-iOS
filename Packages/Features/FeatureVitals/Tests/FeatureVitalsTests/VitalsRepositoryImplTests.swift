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

/// The blood-pressure half of `VitalsRepositoryImpl.kt:46-65`, over the same in-memory database.
///
/// A suite of its own rather than more cases in the one above, because the three halves are three
/// types' worth of setup and one struct holding all of it would be past the type-body budget.
///
/// There is deliberately **no `observeLatestBloodPressure`** to cover: Android has none either
/// (`VitalsRepository.kt`), and the header's "latest" comes from the first row of the window.
@Suite("VitalsRepositoryImpl — blood pressure")
struct VitalsRepositoryImplBloodPressureTests {
    private static let seededAt = Date(timeIntervalSince1970: 1_700_000_000)
    private static let zone = FixedSalusClock.defaultZone

    /// `VitalsRepositoryImpl.kt:59-61` — the write goes through `BloodPressureEntry.toRecord`, so
    /// the row carries the discriminator, the unit and the three value slots the other platform
    /// reads back.
    @Test("saveBloodPressureEntry writes a BLOOD_PRESSURE row for the given profile")
    func saveBloodPressureEntryWritesARow() async throws {
        let fixture = try makeVitalsFixture()

        try await fixture.repository.saveBloodPressureEntry(Self.entry(id: "bp1"))

        let record = try #require(try await fixture.dao.getById("bp1"))
        #expect(record.type == VitalType.bloodPressure.rawValue)
        #expect(record.unit == "mmHg")
        #expect(record.profileId == SalusDatabase.defaultProfileId)
        #expect(record.valuePrimary == 128)
        #expect(record.valueSecondary == 84)
        #expect(record.valueTertiary == 61)
    }

    /// `VitalsRepositoryImpl.kt:56-57` and `:59-61` together, for both shapes a reading can take:
    /// a missing pulse is a `NULL` tertiary column and has to come back as `nil`, not as zero.
    @Test("getBloodPressureEntry reads back what saveBloodPressureEntry wrote, with and without a pulse")
    func getBloodPressureEntryReadsBackWhatSaveWrote() async throws {
        let fixture = try makeVitalsFixture()
        let entries = [
            Self.entry(id: "bp1", note: "after workout"),
            Self.entry(id: "bp2", pulse: nil)
        ]

        for entry in entries {
            try await fixture.repository.saveBloodPressureEntry(entry)
            #expect(try await fixture.repository.getBloodPressureEntry(id: entry.id) == entry)
        }
    }

    /// `VitalsRepositoryImpl.kt:56` — the type guard. Without it a weight row asked for by id
    /// would come back as a reading whose systolic is actually a body weight.
    @Test("getBloodPressureEntry ignores a row of another type")
    func getBloodPressureEntryIgnoresARowOfAnotherType() async throws {
        let fixture = try makeVitalsFixture()
        try await fixture.repository.saveWeightEntry(
            WeightEntry(id: "w1", measuredAt: Self.seededAt, timeZone: Self.zone, kilograms: 82.5, note: nil)
        )

        #expect(try await fixture.repository.getBloodPressureEntry(id: "w1") == nil)
    }

    /// `VitalsRepositoryImpl.kt:46-54` — oldest first, and the window is closed at both ends
    /// because the DAO's `BETWEEN` is.
    @Test("observeBloodPressureHistory emits the window's rows, oldest first, both ends included")
    func observeBloodPressureHistoryEmitsTheWindowsRows() async throws {
        let fixture = try makeVitalsFixture()
        let from = Self.seededAt
        let until = Self.seededAt.addingTimeInterval(200)
        try await fixture.repository.saveBloodPressureEntry(Self.entry(id: "before", at: from.addingTimeInterval(-1)))
        try await fixture.repository.saveBloodPressureEntry(Self.entry(id: "last", at: until))
        try await fixture.repository.saveBloodPressureEntry(Self.entry(id: "first", at: from))
        try await fixture.repository.saveBloodPressureEntry(Self.entry(id: "after", at: until.addingTimeInterval(1)))

        var iterator = fixture.repository.observeBloodPressureHistory(from: from, until: until).makeAsyncIterator()
        let history = try #require(try await iterator.next())

        #expect(history.map(\.id) == ["first", "last"])
    }

    /// `VitalsRepositoryImpl.kt:63-65` — by id alone, with no type clause, exactly as on Android.
    @Test("deleteBloodPressureEntry removes the row")
    func deleteBloodPressureEntryRemovesTheRow() async throws {
        let fixture = try makeVitalsFixture()
        try await fixture.repository.saveBloodPressureEntry(Self.entry(id: "bp1"))

        try await fixture.repository.deleteBloodPressureEntry(id: "bp1")

        #expect(try await fixture.repository.getBloodPressureEntry(id: "bp1") == nil)
    }

    private static func entry(
        id: String,
        pulse: Double? = 61,
        at instant: Date = seededAt,
        note: String? = nil
    ) -> BloodPressureEntry {
        BloodPressureEntry(
            id: id,
            measuredAt: instant,
            timeZone: zone,
            systolic: 128,
            diastolic: 84,
            pulse: pulse,
            note: note
        )
    }
}

/// The glucose half of `VitalsRepositoryImpl.kt:67-86`, over the same in-memory database. Its own
/// suite for `VitalsRepositoryImplBloodPressureTests`' reason.
@Suite("VitalsRepositoryImpl — glucose")
struct VitalsRepositoryImplGlucoseTests {
    private static let seededAt = Date(timeIntervalSince1970: 1_700_000_000)
    private static let zone = FixedSalusClock.defaultZone

    /// `VitalsRepositoryImpl.kt:80-82` — storage is always mg/dL, and the measurement context is
    /// stored under the Kotlin constant name.
    @Test("saveGlucoseEntry writes a BLOOD_GLUCOSE row measured in mg/dL")
    func saveGlucoseEntryWritesARow() async throws {
        let fixture = try makeVitalsFixture()

        try await fixture.repository.saveGlucoseEntry(Self.entry(id: "g1", context: .fasting))

        let record = try #require(try await fixture.dao.getById("g1"))
        #expect(record.type == VitalType.bloodGlucose.rawValue)
        #expect(record.unit == "mg/dL")
        #expect(record.profileId == SalusDatabase.defaultProfileId)
        #expect(record.valuePrimary == 108)
        #expect(record.valueSecondary == nil)
        #expect(record.measurementContext == "FASTING")
    }

    /// `VitalsRepositoryImpl.kt:77-78` and `:80-82` together, with and without a context — the
    /// column is nullable, and a reading taken at no particular time is still a reading.
    @Test("getGlucoseEntry reads back what saveGlucoseEntry wrote, with and without a context")
    func getGlucoseEntryReadsBackWhatSaveWrote() async throws {
        let fixture = try makeVitalsFixture()
        let entries = [
            Self.entry(id: "g1", context: .postMeal, note: "after lunch"),
            Self.entry(id: "g2", context: nil)
        ]

        for entry in entries {
            try await fixture.repository.saveGlucoseEntry(entry)
            #expect(try await fixture.repository.getGlucoseEntry(id: entry.id) == entry)
        }
    }

    /// `VitalsRepositoryImpl.kt:77` — the type guard.
    @Test("getGlucoseEntry ignores a row of another type")
    func getGlucoseEntryIgnoresARowOfAnotherType() async throws {
        let fixture = try makeVitalsFixture()
        try await fixture.repository.saveWeightEntry(
            WeightEntry(id: "w1", measuredAt: Self.seededAt, timeZone: Self.zone, kilograms: 82.5, note: nil)
        )

        #expect(try await fixture.repository.getGlucoseEntry(id: "w1") == nil)
    }

    /// `VitalsRepositoryImpl.kt:67-75`.
    @Test("observeGlucoseHistory emits the window's rows, oldest first, both ends included")
    func observeGlucoseHistoryEmitsTheWindowsRows() async throws {
        let fixture = try makeVitalsFixture()
        let from = Self.seededAt
        let until = Self.seededAt.addingTimeInterval(200)
        try await fixture.repository.saveGlucoseEntry(Self.entry(id: "before", at: from.addingTimeInterval(-1)))
        try await fixture.repository.saveGlucoseEntry(Self.entry(id: "last", at: until))
        try await fixture.repository.saveGlucoseEntry(Self.entry(id: "first", at: from))
        try await fixture.repository.saveGlucoseEntry(Self.entry(id: "after", at: until.addingTimeInterval(1)))

        var iterator = fixture.repository.observeGlucoseHistory(from: from, until: until).makeAsyncIterator()
        let history = try #require(try await iterator.next())

        #expect(history.map(\.id) == ["first", "last"])
    }

    /// `VitalsRepositoryImpl.kt:84-86`.
    @Test("deleteGlucoseEntry removes the row")
    func deleteGlucoseEntryRemovesTheRow() async throws {
        let fixture = try makeVitalsFixture()
        try await fixture.repository.saveGlucoseEntry(Self.entry(id: "g1", context: nil))

        try await fixture.repository.deleteGlucoseEntry(id: "g1")

        #expect(try await fixture.repository.getGlucoseEntry(id: "g1") == nil)
    }

    private static func entry(
        id: String,
        context: MeasurementContext? = nil,
        at instant: Date = seededAt,
        note: String? = nil
    ) -> GlucoseEntry {
        GlucoseEntry(
            id: id,
            measuredAt: instant,
            timeZone: zone,
            mgDl: 108,
            measurementContext: context,
            note: note
        )
    }
}

/// The repository over a fresh in-memory database, shared by the two suites above. A free function
/// rather than a base class, because Swift Testing suites are structs and have no inheritance.
private func makeVitalsFixture() throws -> (repository: VitalsRepositoryImpl, dao: VitalsDao) {
    let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_700_000_000))
    let dao = try VitalsDao(database: SalusDatabase.inMemory(clock: clock))
    return (VitalsRepositoryImpl(vitalsDao: dao), dao)
}
