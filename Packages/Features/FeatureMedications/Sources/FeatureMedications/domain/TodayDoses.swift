// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/domain/TodayDoses.kt:1-154` (Android M15, `529a30f`).
//
// PURE SWIFT, like the Kotlin object: no clock, no view framework, no repository. The caller says
// which day it is summarising and what minute it is, which is exactly what makes the per-emission
// clock read in `MedicationsViewModel` / `MedicationDetailViewModel` load-bearing — a stale day
// gets a perfectly consistent answer about the WRONG day, and the dose handed back is what the
// "take now" button writes into a health record.
//
// Kotlin's `object` becomes a caseless `enum`, this port's house spelling for a namespace of static
// members (`DoseOccurrenceGenerator.swift`, `RecordedDoseRatio.swift`). The two private extension
// functions Kotlin hangs off `MedicationSchedule` and `IntakeStatus` are `fileprivate` extensions
// here, for the same reason they are private there: nothing outside this file may read the rate of
// a schedule without the sum around it.

import SalusModel

/// One dose slot of a single day that carries no `TAKEN`/`SKIPPED` record yet
/// (`TodayDoses.kt:10-15`).
public struct PendingDose: Equatable, Hashable, Sendable {
    public let scheduleId: String
    public let epochDay: Int
    public let minuteOfDay: Int

    public init(scheduleId: String, epochDay: Int, minuteOfDay: Int) {
        self.scheduleId = scheduleId
        self.epochDay = epochDay
        self.minuteOfDay = minuteOfDay
    }
}

/// What one medication's day looks like, as the list card's status chip reports it
/// (`TodayDoses.kt:17-30`).
public enum MedicationDayStatus: Sendable {
    /// At least one of today's dose slots has no record.
    case pending

    /// Every dose slot of today is recorded, and the last recorded one was taken.
    case taken

    /// Every dose slot of today is recorded, and the last recorded one was skipped.
    case skipped

    /// The medication is taken as needed, so the day has no dose slots at all.
    case asNeeded
}

/// What ``TodayDoses/of(medication:logs:todayEpochDay:nowMinuteOfDay:)`` derives for one medication
/// on one day (`TodayDoses.kt:32-40`).
public struct TodayDoseSummary: Equatable, Sendable {
    /// Nil when the day holds no dose slot and the medication is not an as-needed one.
    public let status: MedicationDayStatus?

    /// The earliest unrecorded dose of the day, whether or not its time has come.
    public let nextDoseMinuteOfDay: Int?

    /// The earliest unrecorded dose whose time has already passed; what "take now" records.
    public let dueDose: PendingDose?
}

/// Reads one medication's day out of the dose slots its schedules expand to and the intake rows
/// that were written for them (`TodayDoses.kt:42-51`).
///
/// A dose is *unrecorded* while no row says `TAKEN` or `SKIPPED` for its (schedule, day, minute)
/// triple. A `PENDING` row is what a snooze writes, so it leaves the dose outstanding rather than
/// settling it; `MISSED` is never written at all. That is the same denominator rule
/// ``RecordedDoseRatio`` carries, seen from a single day.
enum TodayDoses {
    /// `TodayDoses.kt:53-105`.
    static func of(
        medication: MedicationWithSchedules,
        logs: [IntakeLog],
        todayEpochDay: Int,
        nowMinuteOfDay: Int
    ) -> TodayDoseSummary {
        let occurrences = DoseOccurrenceGenerator.occurrencesFor(
            medications: [medication],
            fromEpochDay: todayEpochDay,
            toEpochDay: todayEpochDay
        )
        if occurrences.isEmpty {
            // As-needed schedules expand to nothing on purpose: there is no clock time to miss
            // (`TodayDoses.kt:64-73`).
            let asNeeded = medication.schedules.contains { $0.isActive && $0.recurrence == .asNeeded }
            return TodayDoseSummary(
                status: asNeeded ? .asNeeded : nil,
                nextDoseMinuteOfDay: nil,
                dueDose: nil
            )
        }

        // `associateBy { it.scheduleId to it.minuteOfDay }` (`TodayDoses.kt:75-77`). Kotlin's
        // `associateBy` keeps the LAST row for a duplicated key; `Dictionary(_:uniquingKeysWith:)`
        // with `{ _, latest in latest }` is that rule spelled out.
        let settled = Dictionary(
            logs
                .filter { $0.epochDay == todayEpochDay && $0.status.settlesADose }
                .map { (DoseSlot(scheduleId: $0.scheduleId, minuteOfDay: $0.minuteOfDay), $0) },
            uniquingKeysWith: { _, latest in latest }
        )

        // `sortedBy { it.minuteOfDay }` (`TodayDoses.kt:79-81`). The generator already returns
        // (day, minute, scheduleId) order, so this is a stable re-read of the same order rather
        // than a second sort with a partial key.
        let unrecorded = occurrences
            .filter { settled[DoseSlot(scheduleId: $0.scheduleId, minuteOfDay: $0.minuteOfDay)] == nil }
            .sorted { $0.minuteOfDay < $1.minuteOfDay }

        if let next = unrecorded.first {
            // `TodayDoses.kt:83-91`.
            let due = unrecorded.first { $0.minuteOfDay <= nowMinuteOfDay }
            return TodayDoseSummary(
                status: .pending,
                nextDoseMinuteOfDay: next.minuteOfDay,
                dueDose: due.map {
                    PendingDose(scheduleId: $0.scheduleId, epochDay: $0.epochDay, minuteOfDay: $0.minuteOfDay)
                }
            )
        }

        // Nothing is outstanding, so the day reads as the last dose the user settled
        // (`TodayDoses.kt:93-104`).
        let last = occurrences.max { $0.minuteOfDay < $1.minuteOfDay }
        let lastStatus = last.flatMap {
            settled[DoseSlot(scheduleId: $0.scheduleId, minuteOfDay: $0.minuteOfDay)]?.status
        }
        return TodayDoseSummary(
            status: lastStatus == .skipped ? .skipped : .taken,
            nextDoseMinuteOfDay: nil,
            dueDose: nil
        )
    }

    /// How much of the box an **average** day consumes (`TodayDoses.kt:107-120`).
    ///
    /// Two things are weighted into it. Amounts rather than a count of dose times, because stock is
    /// decremented by `MedicationSchedule.doseAmount` per dose — two tablets twice a day empty a box
    /// of twenty in five days, not ten. And each schedule only consumes on the days it actually
    /// fires, which is the share `dayFraction` computes: an every-third-day injection of three units
    /// costs one unit a day on average, and a Monday-and-Wednesday tablet costs two sevenths of one.
    /// Summing raw amounts instead would understate "N days left" by the whole recurrence factor —
    /// a weekly injection would read as if it were taken every morning.
    static func dosesPerDay(schedules: [MedicationSchedule]) -> Double {
        schedules
            .filter(\.isActive)
            .reduce(0.0) { total, schedule in total + schedule.doseAmount * schedule.dayFraction }
    }

    /// Whole days the remaining stock covers, rounded down; nil when stock is not tracked or when no
    /// dose leaves the box on a given day, which would make the division meaningless
    /// (`TodayDoses.kt:122-131`).
    static func daysOfSupply(stockCount: Double?, schedules: [MedicationSchedule]) -> Int? {
        guard let remaining = stockCount else { return nil }
        let perDay = dosesPerDay(schedules: schedules)
        if perDay <= 0.0 {
            return nil
        }
        // `floor(remaining / perDay).toInt()`. The `Int(exactly:)` guard is `formatAmount`'s: Swift
        // traps converting a `Double` past `Int`'s range where Kotlin's `toInt()` saturates, and a
        // stock count comes from a decimal keypad. A box that large has no meaningful day count on
        // either platform, so it answers nil rather than inventing a clamp Android never shows.
        return Int(exactly: (remaining / perDay).rounded(.down))
    }
}

/// The (schedule, minute) pair Kotlin writes as a `Pair` in its `associateBy`/`in` checks
/// (`TodayDoses.kt:77`, `:80`, `:95`). Swift tuples are not `Hashable`, so the key is a type.
private struct DoseSlot: Hashable {
    let scheduleId: String
    let minuteOfDay: Int
}

extension MedicationSchedule {
    /// The share of calendar days this schedule fires on, the mirror of `RecurrenceRule.occursOn`
    /// — which is what ``DoseOccurrenceGenerator`` expands with, so the two agree by construction.
    /// As-needed doses have no rate at all, which is what makes
    /// ``TodayDoses/daysOfSupply(stockCount:schedules:)`` answer nil for a medication that is only
    /// ever taken on demand (`TodayDoses.kt:133-146`).
    fileprivate var dayFraction: Double {
        switch recurrence {
        case .asNeeded: 0.0

        case .daily: 1.0

        case .daysOfWeek: Double((daysOfWeekMask & TodayDosesDefaults.weekMask).nonzeroBitCount)
            / TodayDosesDefaults.daysPerWeek

        case .intervalDays: intervalDays.flatMap { $0 > 0 ? 1.0 / Double($0) : nil } ?? 0.0
        }
    }
}

extension IntakeStatus {
    /// `IntakeStatus.settlesADose()` (`TodayDoses.kt:148-149`).
    fileprivate var settlesADose: Bool {
        self == .taken || self == .skipped
    }
}

/// Kotlin's two `private const val`s (`TodayDoses.kt:151-153`). A `private` top-level `let` would
/// do, but the repo spells file-scope constants a switch arm reads as a namespace so the values and
/// their comments stay together.
private enum TodayDosesDefaults {
    /// bit 0 = Monday .. bit 6 = Sunday; anything above is not a day.
    static let weekMask = 0b1111111
    static let daysPerWeek = 7.0
}
