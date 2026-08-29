// Covers `data/CycleRepositoryImpl.swift`.
//
// There is no `CycleRepositoryImplTest.kt` to port — Android tests the repository only through the
// ViewModels — so every case here is iOS-only, and each one pins a fact the Kotlin implementation
// states in a comment rather than in a test: that the starter symptom catalog is seeded once, on
// the first collection, and never a second time; that a day log round-trips with its symptom
// selection; that the period list is newest start first.
//
// The database is the **real** one over `SalusDatabase.inMemory`, which is the template's
// RepositoryImpl standard and the shape `MedicationsRepositoryImplTests` set: seeding, the
// `(profile_id, date)` unique index and the entry↔symptom foreign keys are facts about real SQL,
// and a fake DAO would only prove the fake. `SalusDatabase.defaultProfileId` is already seeded by
// the v1 migration, so no profile row has to be written first.
//
// Deterministic by construction: a `FixedSalusClock`, rows written before an observation starts,
// and every emission read by awaiting the stream rather than by sleeping.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel
import SalusTesting
import Testing

@testable import FeatureCycle

@Suite("CycleRepositoryImpl")
struct CycleRepositoryImplTests {
    private static let now = Date(timeIntervalSince1970: 1_755_000_000)

    /// The eight seeded ids, in the order `observeSymptoms` promises: `is_custom ASC, name_key ASC`
    /// over a catalog that is entirely non-custom, so plain alphabetical by key — `acne` first,
    /// which is *not* the declaration order the seed list is written in.
    private static let seededIdsInEmissionOrder = [
        "symptom-acne",
        "symptom-back-pain",
        "symptom-bloating",
        "symptom-cramps",
        "symptom-fatigue",
        "symptom-headache",
        "symptom-mood-swings",
        "symptom-tender-breasts"
    ]

    /// The `onStart` twin. The catalog is empty until somebody looks at it, and the first look is
    /// what fills it — including the `_` → `-` substitution that makes `mood_swings` the row
    /// `symptom-mood-swings`.
    @Test("the first collection of observeSymptoms seeds the eight starter symptoms", .timeLimit(.minutes(1)))
    func theFirstCollectionOfObserveSymptomsSeedsTheEightStarterSymptoms() async throws {
        let fixture = try Self.makeFixture()
        #expect(try await fixture.dao.countSymptoms() == 0)

        var iterator = fixture.repository.observeSymptoms().makeAsyncIterator()
        let emitted = try #require(try await iterator.next())

        #expect(emitted.map(\.id) == Self.seededIdsInEmissionOrder)
        #expect(emitted.allSatisfy { $0.isCustom == false })
        #expect(emitted.allSatisfy { $0.iconToken == nil })
        #expect(emitted.first(where: { $0.id == "symptom-mood-swings" })?.nameKey == "mood_swings")
        #expect(try await fixture.dao.countSymptoms() == 8)
    }

    /// Seeding is guarded by the count, not by a flag the process holds, so a second screen — or
    /// the same screen after a rotation — re-runs the guard and writes nothing.
    @Test("a second collection of observeSymptoms does not seed again", .timeLimit(.minutes(1)))
    func aSecondCollectionOfObserveSymptomsDoesNotSeedAgain() async throws {
        let fixture = try Self.makeFixture()
        var first = fixture.repository.observeSymptoms().makeAsyncIterator()
        _ = try await first.next()

        var second = fixture.repository.observeSymptoms().makeAsyncIterator()
        let emitted = try #require(try await second.next())

        #expect(emitted.map(\.id) == Self.seededIdsInEmissionOrder)
        #expect(try await fixture.dao.countSymptoms() == 8)
    }

    /// A user-added symptom must survive the guard too: the catalog is not empty, so nothing is
    /// seeded over it, and the custom row sorts after the seeded ones (`is_custom ASC`).
    @Test("a non-empty catalog is left alone and keeps custom rows last", .timeLimit(.minutes(1)))
    func aNonEmptyCatalogIsLeftAloneAndKeepsCustomRowsLast() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.dao.upsertSymptoms([
            SymptomRecord(id: "symptom-custom", nameKey: "aaa_custom", isCustom: true, iconToken: nil)
        ])

        var iterator = fixture.repository.observeSymptoms().makeAsyncIterator()
        let emitted = try #require(try await iterator.next())

        #expect(emitted.map(\.id) == ["symptom-custom"])
        #expect(try await fixture.dao.countSymptoms() == 1)
    }

    /// The write and the read back, across the atomic `saveDailyEntry` (divergence (a)): the day
    /// keeps its id, its flow, its mood, its untrimmed note and exactly the symptom ids it was
    /// saved with.
    @Test("saveDayLog then getDayLog round-trips the day and its symptom ids")
    func saveDayLogThenGetDayLogRoundTripsTheDayAndItsSymptomIds() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.dao.upsertSymptoms([
            SymptomRecord(id: "symptom-cramps", nameKey: "cramps", isCustom: false, iconToken: nil),
            SymptomRecord(id: "symptom-acne", nameKey: "acne", isCustom: false, iconToken: nil)
        ])
        let log = CycleDayLog(
            id: "entry-1",
            date: LocalDate(year: 2026, month: 8, day: 16),
            flow: .light,
            mood: .irritable,
            note: " tired ",
            symptomIds: ["symptom-cramps", "symptom-acne"]
        )

        try await fixture.repository.saveDayLog(log)

        let stored = try #require(try await fixture.repository.getDayLog(on: log.date))
        #expect(stored == log)
    }

    /// A re-save *replaces* the symptom set rather than merging into it, which is what unticking
    /// the last symptom of a day depends on.
    @Test("saveDayLog replaces the symptom set of the day it rewrites")
    func saveDayLogReplacesTheSymptomSetOfTheDayItRewrites() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.dao.upsertSymptoms([
            SymptomRecord(id: "symptom-cramps", nameKey: "cramps", isCustom: false, iconToken: nil)
        ])
        let date = LocalDate(year: 2026, month: 8, day: 16)
        try await fixture.repository.saveDayLog(Self.dayLog(date: date, symptomIds: ["symptom-cramps"]))

        try await fixture.repository.saveDayLog(Self.dayLog(date: date, symptomIds: []))

        let stored = try #require(try await fixture.repository.getDayLog(on: date))
        #expect(stored.symptomIds.isEmpty)
    }

    /// A day nobody logged is `nil`, not an empty log — the editor opens blank rather than showing
    /// a record that does not exist.
    @Test("getDayLog answers nil for a day with no entry")
    func getDayLogAnswersNilForADayWithNoEntry() async throws {
        let fixture = try Self.makeFixture()

        #expect(try await fixture.repository.getDayLog(on: LocalDate(year: 2026, month: 8, day: 16)) == nil)
    }

    /// The DAO's `ORDER BY start_date DESC`, carried through the mapper: the calendar and the list
    /// both read the newest period first.
    @Test("observePeriods emits the profile's periods newest start first", .timeLimit(.minutes(1)))
    func observePeriodsEmitsThePeriodsNewestStartFirst() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.savePeriod(Self.period(
            id: "older",
            start: LocalDate(year: 2026, month: 7, day: 1)
        ))
        try await fixture.repository.savePeriod(Self.period(
            id: "newer",
            start: LocalDate(year: 2026, month: 8, day: 1)
        ))

        var iterator = fixture.repository.observePeriods().makeAsyncIterator()
        let emitted = try #require(try await iterator.next())

        #expect(emitted.map(\.id) == ["newer", "older"])
        #expect(emitted.first?.startDate == LocalDate(year: 2026, month: 8, day: 1))
    }

    /// The three single-row period reads and the delete, which the editor drives in that order:
    /// look the day up, find whether a period is still running, then remove one.
    @Test("savePeriod is readable by start day and as the open period, and deletePeriod removes it")
    func savePeriodIsReadableByStartDayAndAsTheOpenPeriodAndDeleteRemovesIt() async throws {
        let fixture = try Self.makeFixture()
        let start = LocalDate(year: 2026, month: 8, day: 1)
        let closed = Self.period(
            id: "closed",
            start: LocalDate(year: 2026, month: 7, day: 1),
            end: LocalDate(year: 2026, month: 7, day: 5)
        )
        try await fixture.repository.savePeriod(closed)
        try await fixture.repository.savePeriod(Self.period(id: "open", start: start))

        #expect(try await fixture.repository.getPeriodStartingOn(start)?.id == "open")
        #expect(try await fixture.repository.getPeriodStartingOn(start.plusDays(1)) == nil)
        let open = try #require(try await fixture.repository.getOpenPeriod())
        #expect(open.id == "open")
        #expect(open.isOpen)

        try await fixture.repository.deletePeriod(id: "open")

        #expect(try await fixture.repository.getOpenPeriod() == nil)
        #expect(try await fixture.repository.getPeriodStartingOn(start) == nil)
    }

    /// The repository is scoped to one profile, and the scoping is the DAO's `profile_id`
    /// argument rather than a filter applied afterwards.
    @Test("a period saved under another profile is invisible", .timeLimit(.minutes(1)))
    func aPeriodSavedUnderAnotherProfileIsInvisible() async throws {
        let fixture = try Self.makeFixture()
        try await fixture.repository.savePeriod(Self.period(id: "mine", start: LocalDate(year: 2026, month: 8, day: 1)))
        let otherProfile = CycleRepositoryImpl(cycleDao: fixture.dao, profileId: "someone-else")

        var iterator = otherProfile.observePeriods().makeAsyncIterator()

        let emitted = try #require(try await iterator.next())
        #expect(emitted.isEmpty)
    }

    // MARK: - Fixtures

    private static func makeFixture() throws -> (repository: CycleRepositoryImpl, dao: CycleDao) {
        let dao = try CycleDao(database: SalusDatabase.inMemory(clock: FixedSalusClock(now: now)))
        return (CycleRepositoryImpl(cycleDao: dao, profileId: SalusDatabase.defaultProfileId), dao)
    }

    private static func period(id: String, start: LocalDate, end: LocalDate? = nil) -> CyclePeriod {
        CyclePeriod(id: id, startDate: start, endDate: end, flowPeak: .medium, note: nil, createdAt: now)
    }

    private static func dayLog(date: LocalDate, symptomIds: Set<String>) -> CycleDayLog {
        CycleDayLog(id: "entry-1", date: date, flow: .light, mood: .good, note: nil, symptomIds: symptomIds)
    }
}
