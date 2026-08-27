// iOS-only table: `RecordedDoseRatio` has no Kotlin twin. It replaces an Android calculator whose
// name and whose whole framing are built on a stem `BannedHealthClaims` forbids (CLAUDE.md,
// "Copy and localisation rules"), and it is a different computation as well as a different name:
// the Android one divides TAKEN by the occurrences the generator expands, which turns the absence
// of a record into a statement about someone's treatment. This one divides TAKEN by the doses the
// user actually RECORDED, so a medication nobody logged is absent from the result rather than
// scored at zero. Android owes the mirror change; opened in
// `salus-android/docs/ios-v1-plan.md` 11.

import SalusModel
import Testing

@testable import FeatureMedications

@Suite("RecordedDoseRatio")
struct RecordedDoseRatioTests {
    @Test("the ratio is taken over recorded, per medication")
    func theRatioIsTakenOverRecordedPerMedication() {
        let logs = [
            testLog(id: "a", medicationId: "med-1", epochDay: 10, status: .taken),
            testLog(id: "b", medicationId: "med-1", epochDay: 11, status: .taken),
            testLog(id: "c", medicationId: "med-1", epochDay: 12, status: .skipped),
            testLog(id: "d", medicationId: "med-2", epochDay: 10, status: .taken)
        ]

        let result = RecordedDoseRatio.perMedication(logs: logs, fromEpochDay: 10, toEpochDay: 12)

        #expect(result == ["med-1": 2.0 / 3.0, "med-2": 1.0])
    }

    @Test("a medication with no recorded dose is absent from the result")
    func aMedicationWithNoRecordedDoseIsAbsentFromTheResult() {
        let logs = [testLog(id: "a", medicationId: "med-1", epochDay: 10, status: .taken)]

        let result = RecordedDoseRatio.perMedication(logs: logs, fromEpochDay: 10, toEpochDay: 12)

        // Not 0.0 for "med-2": nothing was recorded for it, so there is no fraction to report.
        #expect(result.keys.sorted() == ["med-1"])
        #expect(RecordedDoseRatio.perMedication(logs: [], fromEpochDay: 10, toEpochDay: 12).isEmpty)
    }

    @Test("the day window is inclusive at both ends")
    func theDayWindowIsInclusiveAtBothEnds() {
        let logs = [
            testLog(id: "before", epochDay: 9, status: .skipped),
            testLog(id: "from", epochDay: 10, status: .taken),
            testLog(id: "to", epochDay: 12, status: .taken),
            testLog(id: "after", epochDay: 13, status: .skipped)
        ]

        let result = RecordedDoseRatio.perMedication(logs: logs, fromEpochDay: 10, toEpochDay: 12)

        // Both boundary days count and both are TAKEN, so the two out-of-window SKIPPED rows
        // would have dragged the fraction below 1.0 had either leaked in.
        #expect(result == ["med-1": 1.0])
    }

    @Test("a status other than taken counts in the denominator only")
    func aStatusOtherThanTakenCountsInTheDenominatorOnly() {
        let logs = [
            testLog(id: "a", epochDay: 10, status: .taken),
            testLog(id: "b", epochDay: 11, status: .skipped),
            testLog(id: "c", epochDay: 12, status: .pending)
        ]

        let result = RecordedDoseRatio.perMedication(logs: logs, fromEpochDay: 10, toEpochDay: 12)

        #expect(result == ["med-1": 1.0 / 3.0])
    }
}
