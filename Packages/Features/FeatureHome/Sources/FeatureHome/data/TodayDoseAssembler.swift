// Ported 1:1 from the `internal object TodayDoseAssembler` at the bottom of
// `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/data/TodayRepositoryImpl.kt`
// (`:133-185`).
//
// It is a file of its own here rather than a second declaration inside `TodayRepositoryImpl.swift`,
// which is the only structural difference: Swift has no `internal object` beside a class in the
// same file that reads as a separate unit, and the repository is long enough without it. The
// Kotlin's reason for extracting it — "pure entity → dashboard-model join; extracted from the
// repository for direct JVM testing" — is the same reason it is testable here without a database.
//
// `enum` rather than `struct`: a caseless enum is Swift's uninstantiable namespace, the shape
// `RecurrenceRule` and `CycleMappers` already use for a Kotlin `object` with no state.
//
// One expression differs and it is the same value: Kotlin looks the recurrence up as
// `Recurrence.entries.firstOrNull { it.name == schedule.recurrence }`, Swift as
// `Recurrence(rawValue:)`. The `Recurrence` raw values *are* the Kotlin constant names
// (`Medication.swift:25-30`), so both answer `nil` for exactly the same unparsable strings.

import SalusDatabase
import SalusModel

/// Pure record → dashboard-model join (`TodayRepositoryImpl.kt:133-185`).
///
/// Internal on purpose: with `TodayRepositoryImpl` it is one of the only two files in this package
/// that sees a `SalusDatabase` record, and nothing outside the package constructs either.
enum TodayDoseAssembler {
    /// How long after its scheduled minute a dose is still merely late rather than missed
    /// (`TodayRepositoryImpl.kt:136`).
    static let graceMinutes = 60

    /// Today's dose slots, sorted by time and then by medication name
    /// (`TodayRepositoryImpl.kt:138-173`).
    ///
    /// - Parameters:
    ///   - medications: the profile's active medications; a schedule whose medication is missing
    ///     from this list is dropped.
    ///   - schedules: every active schedule of the profile, of any recurrence.
    ///   - logs: the recorded doses of `today` only — the key is `(scheduleId, scheduledMinutes)`,
    ///     so a log from another day would resolve the wrong slot.
    ///   - today: the day being assembled, as an epoch day.
    ///   - nowMinute: minutes since local midnight, for the grace comparison.
    static func assemble(
        medications: [MedicationRecord],
        schedules: [MedicationScheduleRecord],
        logs: [MedicationIntakeLogRecord],
        today: Int,
        nowMinute: Int
    ) -> [TodayDose] {
        // `associateBy`'s twin: last one wins on a duplicate key, which is what Kotlin does too.
        let medicationsById = Dictionary(medications.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        let logsByKey = Dictionary(
            logs.map { (DoseSlot(scheduleId: $0.scheduleId, minuteOfDay: $0.scheduledMinutes), $0) },
            uniquingKeysWith: { _, last in last }
        )

        return schedules
            .compactMap { schedule -> TodayDose? in
                guard let medication = medicationsById[schedule.medicationId],
                      today >= medication.startDateEpochDay,
                      medication.endDateEpochDay.map({ today <= $0 }) ?? true,
                      let recurrence = Recurrence(rawValue: schedule.recurrence),
                      RecurrenceRule.occursOn(
                          recurrence: recurrence,
                          daysOfWeekMask: schedule.daysOfWeekMask,
                          intervalDays: schedule.intervalDays,
                          anchorEpochDay: schedule.anchorDateEpochDay,
                          epochDay: today
                      )
                else {
                    return nil
                }

                let slot = DoseSlot(scheduleId: schedule.id, minuteOfDay: schedule.timeOfDayMinutes)
                return TodayDose(
                    scheduleId: schedule.id,
                    medicationId: medication.id,
                    medicationName: medication.name,
                    minuteOfDay: schedule.timeOfDayMinutes,
                    doseAmount: schedule.doseAmount,
                    status: resolveStatus(log: logsByKey[slot], schedule: schedule, nowMinute: nowMinute)
                )
            }
            .sorted { lhs, rhs in
                // `compareBy({ it.minuteOfDay }, { it.medicationName })`, spelled out because Swift
                // has no comparator chain.
                lhs.minuteOfDay == rhs.minuteOfDay
                    ? lhs.medicationName < rhs.medicationName
                    : lhs.minuteOfDay < rhs.minuteOfDay
            }
    }

    /// `TodayRepositoryImpl.kt:175-184`, precedence included.
    ///
    /// `>` and not `>=`: at exactly `timeOfDayMinutes + graceMinutes` the dose is still pending.
    private static func resolveStatus(
        log: MedicationIntakeLogRecord?,
        schedule: MedicationScheduleRecord,
        nowMinute: Int
    ) -> DoseStatus {
        if log?.status == IntakeStatus.taken.rawValue {
            return .taken
        }
        if let log, log.snoozedUntilEpochMs != nil, log.status == IntakeStatus.pending.rawValue {
            return .snoozed
        }
        if nowMinute > schedule.timeOfDayMinutes + graceMinutes {
            return .missed
        }
        return .pending
    }

    /// The `(scheduleId, scheduledMinutes)` pair Kotlin writes as a `Pair`. A named type because
    /// Swift tuples are not `Hashable` enough to be dictionary keys.
    private struct DoseSlot: Hashable {
        let scheduleId: String
        let minuteOfDay: Int
    }
}
