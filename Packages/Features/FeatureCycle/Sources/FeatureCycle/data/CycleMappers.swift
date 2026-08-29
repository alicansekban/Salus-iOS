// Ported 1:1 from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/data/
// CycleMappers.kt`.
//
// The Kotlin functions are `internal` extensions on the Room entities; these are `internal` static
// functions on one `enum` namespace instead. `SalusDatabase`'s records live in another module, and
// an extension on `CyclePeriodRecord` declared here would put `toDomain()` on that public type for
// every file in this package — including the ViewModels, which have no business seeing a record at
// all. A namespace keeps the whole record↔domain boundary in one place, which is exactly what
// `CLAUDE.md`'s "records never leave `SalusDatabase`" rule is protecting. Recorded in the M6
// execution record without a letter (it is a shape, not a behaviour): `MedicationMapper.swift`
// uses extensions; the two shapes do the same thing and the reach is the difference.
//
// **The two enums fall back to `nil` rather than throwing.** Kotlin reads them with
// `entries.firstOrNull { it.name == this }`, so a `flow_peak` or `mood` this build cannot spell —
// a value written by a newer Android and restored from a backup — reads as "not recorded" and the
// rest of the row survives. `FlowLevel(rawValue:)` / `Mood(rawValue:)` is the same lookup, and the
// `nil` is the port rather than a shortcut: a period whose peak flow cannot be read is still a
// period the calendar has to draw.
//
// **The note is passed through untrimmed**, in both directions. Trimming is the editor's job; a
// mapper that trimmed would make a round trip lossy for a row the user really did save with a
// trailing space.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel

/// Turns `SalusDatabase`'s cycle records into the feature's domain types and back.
enum CycleMappers {
    /// Severity is not editable in v1; every selected symptom is stored with this value
    /// (`CycleMappers.kt:16-17`).
    static let defaultSymptomSeverity = 1

    /// `CycleMappers.kt:19-27`.
    static func toDomain(_ record: CyclePeriodRecord) -> CyclePeriod {
        CyclePeriod(
            id: record.id,
            startDate: LocalDate(epochDay: record.startDateEpochDay),
            endDate: record.endDateEpochDay.map { LocalDate(epochDay: $0) },
            flowPeak: record.flowPeak.flatMap { FlowLevel(rawValue: $0) },
            note: record.note,
            createdAt: Date(epochMilliseconds: record.createdAtEpochMs)
        )
    }

    /// `CycleMappers.kt:29-38`.
    static func toRecord(_ period: CyclePeriod, profileId: String) -> CyclePeriodRecord {
        CyclePeriodRecord(
            id: period.id,
            profileId: profileId,
            startDateEpochDay: period.startDate.epochDay,
            endDateEpochDay: period.endDate?.epochDay,
            flowPeak: period.flowPeak?.rawValue,
            note: period.note,
            createdAtEpochMs: period.createdAt.epochMilliseconds
        )
    }

    /// `CycleMappers.kt:40-47`. The symptom ids are a second read — the links live in their own
    /// table — so the caller hands them in rather than the mapper reaching for them.
    static func toDomain(_ record: CycleDailyEntryRecord, symptomIds: Set<String>) -> CycleDayLog {
        CycleDayLog(
            id: record.id,
            date: LocalDate(epochDay: record.dateEpochDay),
            flow: record.flow.flatMap { FlowLevel(rawValue: $0) },
            mood: record.mood.flatMap { Mood(rawValue: $0) },
            note: record.note,
            symptomIds: symptomIds
        )
    }

    /// `CycleMappers.kt:49-56`.
    static func toRecord(_ log: CycleDayLog, profileId: String) -> CycleDailyEntryRecord {
        CycleDailyEntryRecord(
            id: log.id,
            profileId: profileId,
            dateEpochDay: log.date.epochDay,
            flow: log.flow?.rawValue,
            mood: log.mood?.rawValue,
            note: log.note
        )
    }

    /// One link per selected symptom, all at ``defaultSymptomSeverity`` (`CycleMappers.kt:58-65`).
    ///
    /// The ids are sorted first, which Kotlin does not do — recorded divergence (m), and a Swift
    /// one: Kotlin's `Set` is a `LinkedHashSet`, so `map` there walks insertion order, while a
    /// Swift `Set`'s order is seeded per process and would hand the same day's links to the DAO in
    /// a different sequence on every launch. The resulting table is identical either way — the
    /// primary key is `(entry_id, symptom_id)` — so this buys a reproducible write rather than a
    /// different one.
    static func toSymptomLinks(_ log: CycleDayLog) -> [CycleEntrySymptomRecord] {
        log.symptomIds.sorted().map { symptomId in
            CycleEntrySymptomRecord(
                entryId: log.id,
                symptomId: symptomId,
                severity: defaultSymptomSeverity
            )
        }
    }

    /// `CycleMappers.kt:67-72`.
    static func toDomain(_ record: SymptomRecord) -> Symptom {
        Symptom(
            id: record.id,
            nameKey: record.nameKey,
            isCustom: record.isCustom,
            iconToken: record.iconToken
        )
    }
}
