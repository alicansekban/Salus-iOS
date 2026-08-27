// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/domain/DoseOccurrenceGenerator.kt`.

import SalusModel

/// PURE SWIFT. Expands medication schedules into concrete dose occurrences for a day range.
/// The Kotlin twin of this file says it is "ported 1:1 to Swift for iOS, so no platform types and
/// no clock access — callers pass days"; this is that port, and the constraint holds here too.
///
/// Day arithmetic runs entirely on epochDay ints; epochDay 0 = 1970-01-01, a Thursday.
enum DoseOccurrenceGenerator {
    /// Inclusive [fromEpochDay, toEpochDay]. Output is sorted by (day, minute, scheduleId).
    static func occurrencesFor(
        medications: [MedicationWithSchedules],
        fromEpochDay: Int,
        toEpochDay: Int
    ) -> [DoseOccurrence] {
        if fromEpochDay > toEpochDay {
            return []
        }

        var result: [DoseOccurrence] = []
        for entry in medications {
            let medication = entry.medication
            if !medication.isActive {
                continue
            }
            let medFrom = max(fromEpochDay, medication.startDateEpochDay)
            let medTo = medication.endDateEpochDay.map { min(toEpochDay, $0) } ?? toEpochDay
            if medFrom > medTo {
                continue
            }

            for schedule in entry.schedules {
                if !schedule.isActive {
                    continue
                }
                for day in medFrom ... medTo where occursOn(schedule: schedule, epochDay: day) {
                    result.append(
                        DoseOccurrence(
                            scheduleId: schedule.id,
                            medicationId: medication.id,
                            epochDay: day,
                            minuteOfDay: schedule.timeOfDayMinutes
                        )
                    )
                }
            }
        }
        // Kotlin's `sortedWith(compareBy(...))` is a STABLE sort; Swift's `sorted(by:)` is not, so
        // the tie-break chain has to be total for the two platforms to agree. It is: the
        // (day, minute, scheduleId) triple is the idempotency key, so no two occurrences can share
        // all three.
        return result.sorted { lhs, rhs in
            if lhs.epochDay != rhs.epochDay {
                return lhs.epochDay < rhs.epochDay
            }
            if lhs.minuteOfDay != rhs.minuteOfDay {
                return lhs.minuteOfDay < rhs.minuteOfDay
            }
            return lhs.scheduleId < rhs.scheduleId
        }
    }

    static func occursOn(schedule: MedicationSchedule, epochDay: Int) -> Bool {
        RecurrenceRule.occursOn(
            recurrence: schedule.recurrence,
            daysOfWeekMask: schedule.daysOfWeekMask,
            intervalDays: schedule.intervalDays,
            anchorEpochDay: schedule.anchorDateEpochDay,
            epochDay: epochDay
        )
    }
}
