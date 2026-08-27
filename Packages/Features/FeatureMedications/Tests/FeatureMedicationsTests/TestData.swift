// Ported 1:1 from `feature/medications/src/test/kotlin/com/alicansekban/salus/feature/
// medications/TestData.kt`.
//
// The two builders and every default value are Kotlin's, so a case that reads
// `testSchedule(recurrence: .daysOfWeek, daysOfWeekMask: 0b101)` on either platform is
// describing the same schedule. Kotlin's named-argument defaults map onto Swift's directly.

import SalusCommon
import SalusModel

@testable import FeatureMedications

/// `TestData.kt:8-30`.
func testMedication(
    id: String = "med-1",
    name: String = "Aspirin",
    startDateEpochDay: Int = 0,
    endDateEpochDay: Int? = nil,
    stockCount: Double? = nil,
    stockThreshold: Double? = nil,
    isActive: Bool = true,
    remindersEnabled: Bool = true
) -> Medication {
    Medication(
        id: id,
        name: name,
        form: .tablet,
        strengthValue: 500.0,
        strengthUnit: "mg",
        instructions: nil,
        stockCount: stockCount,
        stockThreshold: stockThreshold,
        startDateEpochDay: startDateEpochDay,
        endDateEpochDay: endDateEpochDay,
        isActive: isActive,
        remindersEnabled: remindersEnabled
    )
}

/// `TestData.kt:32-52`.
func testSchedule(
    id: String = "sch-1",
    medicationId: String = "med-1",
    recurrence: Recurrence = .daily,
    daysOfWeekMask: Int = 0,
    intervalDays: Int? = nil,
    anchorDateEpochDay: Int = 0,
    timeOfDayMinutes: Int = 8 * 60,
    doseAmount: Double = 1.0,
    isActive: Bool = true
) -> MedicationSchedule {
    MedicationSchedule(
        id: id,
        medicationId: medicationId,
        recurrence: recurrence,
        daysOfWeekMask: daysOfWeekMask,
        intervalDays: intervalDays,
        anchorDateEpochDay: anchorDateEpochDay,
        timeOfDayMinutes: timeOfDayMinutes,
        doseAmount: doseAmount,
        isActive: isActive
    )
}

/// The iOS-only builder the recorded-dose ratio needs; Kotlin's table builds its logs inline.
func testLog(
    id: String = "log-1",
    scheduleId: String = "sch-1",
    medicationId: String = "med-1",
    epochDay: Int,
    minuteOfDay: Int = 8 * 60,
    status: IntakeStatus = .taken,
    doseAmount: Double = 1.0
) -> IntakeLog {
    IntakeLog(
        id: id,
        scheduleId: scheduleId,
        medicationId: medicationId,
        epochDay: epochDay,
        minuteOfDay: minuteOfDay,
        status: status,
        takenAtEpochMs: nil,
        snoozedUntilEpochMs: nil,
        doseAmount: doseAmount,
        note: nil
    )
}

/// The twin of Kotlin's `IdGenerator { "generated-id" }` SAM lambda
/// (`IntakeActionUseCasesTest.kt:30`): an id source that cannot vary, so the seeded log's id is
/// an assertable value rather than a fresh UUID.
struct FixedIdGenerator: IdGenerator {
    let id: String

    func newId() -> String {
        id
    }
}
