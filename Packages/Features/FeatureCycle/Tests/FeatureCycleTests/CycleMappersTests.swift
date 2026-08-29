// Ported 1:1 from `feature/cycle/src/test/kotlin/com/alicansekban/salus/feature/cycle/data/
// CycleMappersTest.kt`.
//
// All five Kotlin case names are carried over verbatim with one substitution: Room's word for a
// row is `entity`, GRDB's is `record`, so `period entity round-trips …` becomes `period record
// round-trips …` and so on — the substitution `MedicationMapperTests` already made (**iOS-M5**
// divergence (g), in that milestone's record — this milestone's own letters are unrelated).
// Nothing else about the cases changes.
//
// Kotlin calls the mappers as extension functions (`entity.toDomain()`); here they are static
// functions on the `CycleMappers` namespace, so the call sites read `CycleMappers.toDomain(record)`
// — see the file header of `CycleMappers.swift`.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel
import Testing

@testable import FeatureCycle

@Suite("CycleMappers")
struct CycleMappersTests {
    private let profileId = "default-profile"
    /// `CycleMappersTest.kt:29` — the one `created_at` every case in the table writes.
    private static let createdAtEpochMs: Int64 = 1_755_000_000_000

    /// `CycleMappersTest.kt:20-38`.
    @Test("period record round-trips through the domain model")
    func periodRecordRoundTripsThroughTheDomainModel() {
        let record = CyclePeriodRecord(
            id: "p1",
            profileId: profileId,
            startDateEpochDay: LocalDate(year: 2026, month: 8, day: 1).epochDay,
            endDateEpochDay: LocalDate(year: 2026, month: 8, day: 5).epochDay,
            flowPeak: FlowLevel.heavy.rawValue,
            note: "note",
            createdAtEpochMs: Self.createdAtEpochMs
        )

        let domain = CycleMappers.toDomain(record)

        #expect(domain.startDate == LocalDate(year: 2026, month: 8, day: 1))
        #expect(domain.endDate == LocalDate(year: 2026, month: 8, day: 5))
        #expect(domain.flowPeak == .heavy)
        #expect(CycleMappers.toRecord(domain, profileId: profileId) == record)
    }

    /// `CycleMappersTest.kt:40-56`. An unreadable `flow_peak` is `nil`, never a throw: a spelling
    /// this build does not know arrives through a backup written by a newer Android, and a period
    /// whose peak flow cannot be read is still a period the calendar has to draw.
    @Test("open period and unknown flow map to nils")
    func openPeriodAndUnknownFlowMapToNils() {
        let record = CyclePeriodRecord(
            id: "p2",
            profileId: profileId,
            startDateEpochDay: LocalDate(year: 2026, month: 8, day: 10).epochDay,
            endDateEpochDay: nil,
            flowPeak: "NOT_A_LEVEL",
            note: nil,
            createdAtEpochMs: Self.createdAtEpochMs
        )

        let domain = CycleMappers.toDomain(record)

        #expect(domain.endDate == nil)
        #expect(domain.flowPeak == nil)
    }

    /// `CycleMappersTest.kt:58-81`.
    @Test("day log maps to record and symptom links with default severity")
    func dayLogMapsToRecordAndSymptomLinksWithDefaultSeverity() {
        let log = CycleDayLog(
            id: "e1",
            date: LocalDate(year: 2026, month: 8, day: 16),
            flow: .light,
            mood: .irritable,
            note: "tired",
            symptomIds: ["symptom-cramps", "symptom-fatigue"]
        )

        let record = CycleMappers.toRecord(log, profileId: profileId)
        let links = CycleMappers.toSymptomLinks(log)

        #expect(record.dateEpochDay == LocalDate(year: 2026, month: 8, day: 16).epochDay)
        #expect(record.flow == FlowLevel.light.rawValue)
        #expect(record.mood == Mood.irritable.rawValue)
        #expect(links.count == 2)
        #expect(Set(links.map(\.symptomId)) == ["symptom-cramps", "symptom-fatigue"])
        for link in links {
            #expect(link.entryId == "e1")
            #expect(link.severity == CycleMappers.defaultSymptomSeverity)
        }
    }

    /// `CycleMappersTest.kt:83-100`.
    @Test("daily entry record maps back to domain with symptoms")
    func dailyEntryRecordMapsBackToDomainWithSymptoms() {
        let record = CycleDailyEntryRecord(
            id: "e2",
            profileId: profileId,
            dateEpochDay: LocalDate(year: 2026, month: 8, day: 12).epochDay,
            flow: FlowLevel.spotting.rawValue,
            mood: Mood.good.rawValue,
            note: nil
        )

        let domain = CycleMappers.toDomain(record, symptomIds: ["symptom-acne"])

        #expect(domain.date == LocalDate(year: 2026, month: 8, day: 12))
        #expect(domain.flow == .spotting)
        #expect(domain.mood == .good)
        #expect(domain.symptomIds == ["symptom-acne"])
    }

    /// `CycleMappersTest.kt:102-111`.
    @Test("symptom record maps to domain")
    func symptomRecordMapsToDomain() {
        let record = SymptomRecord(id: "symptom-cramps", nameKey: "cramps", isCustom: false, iconToken: nil)

        let domain = CycleMappers.toDomain(record)

        #expect(domain.id == "symptom-cramps")
        #expect(domain.nameKey == "cramps")
        #expect(domain.isCustom == false)
    }

    // MARK: - iOS-only

    /// No Kotlin twin: `Instant` ↔ epoch milliseconds is one library call there, while here it is
    /// `SalusCommon`'s hand-written pair, and `createdAt` is the only instant the cycle feature
    /// persists. An unknown `mood` has no Kotlin case either — `CycleMappersTest.kt` covers the
    /// fallback for `flow` only, and the two share one parse rule.
    @Test("createdAt survives the epoch-millisecond column and an unknown mood maps to nil")
    func createdAtSurvivesTheColumnAndAnUnknownMoodMapsToNil() {
        let record = CyclePeriodRecord(
            id: "p3",
            profileId: profileId,
            startDateEpochDay: 20000,
            endDateEpochDay: nil,
            flowPeak: nil,
            note: nil,
            createdAtEpochMs: Self.createdAtEpochMs
        )

        let domain = CycleMappers.toDomain(record)

        #expect(domain.createdAt == Date(epochMilliseconds: Self.createdAtEpochMs))
        #expect(domain.createdAt.epochMilliseconds == Self.createdAtEpochMs)

        let entry = CycleDailyEntryRecord(
            id: "e3",
            profileId: profileId,
            dateEpochDay: 20000,
            flow: nil,
            mood: "NOT_A_MOOD",
            note: nil
        )

        #expect(CycleMappers.toDomain(entry, symptomIds: []).mood == nil)
    }

    /// The mapper hands the note through exactly as it was given — trimming is the editor's job,
    /// and a mapper that trimmed would make `toRecord(toDomain(record)) != record` for a row the
    /// user really did save with a trailing space.
    @Test("the note is passed through untrimmed in both directions")
    func theNoteIsPassedThroughUntrimmed() {
        let record = CyclePeriodRecord(
            id: "p4",
            profileId: profileId,
            startDateEpochDay: 20000,
            endDateEpochDay: nil,
            flowPeak: nil,
            note: "  spaced  ",
            createdAtEpochMs: Self.createdAtEpochMs
        )

        #expect(CycleMappers.toDomain(record).note == "  spaced  ")

        let log = CycleDayLog(
            id: "e4",
            date: LocalDate(epochDay: 20000),
            flow: nil,
            mood: nil,
            note: " tired ",
            symptomIds: []
        )

        #expect(CycleMappers.toRecord(log, profileId: profileId).note == " tired ")
    }

    /// The empty selection is a real state — a day whose symptoms were all unticked — and it has
    /// to reach the DAO as an empty link list rather than as "nothing to write", because
    /// `saveDailyEntry` replaces the set with what it is given.
    @Test("a day log with no symptoms maps to no links")
    func aDayLogWithNoSymptomsMapsToNoLinks() {
        let log = CycleDayLog(
            id: "e5",
            date: LocalDate(epochDay: 20000),
            flow: nil,
            mood: nil,
            note: nil,
            symptomIds: []
        )

        #expect(CycleMappers.toSymptomLinks(log).isEmpty)
    }
}
