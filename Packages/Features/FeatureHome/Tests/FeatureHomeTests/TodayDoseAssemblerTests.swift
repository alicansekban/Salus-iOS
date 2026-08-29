// Ported 1:1 from `feature/home/src/test/kotlin/com/alicansekban/salus/feature/home/data/
// TodayDoseAssemblerTest.kt`.
//
// Five cases, in the Kotlin order, with the Kotlin fixture (`today = 20_000`) and the Kotlin
// inputs; each display name is the backticked Kotlin name verbatim, so a case renamed on one
// platform and not the other is visible in the diff. Each one cites the Kotlin lines it comes from.
//
// The three private builders are the Kotlin file's, over `SalusDatabase`'s records rather than
// Room's entities — the same field names in the same order, so the fixtures read as one file.
// Kotlin's `schedule(recurrence: String)` takes the enum here instead: the Swift `Recurrence` raw
// values *are* the Kotlin constant names, so `Recurrence.daily.rawValue` is `"DAILY"` and passing
// the enum makes an unparsable name impossible to write by accident. The one case that needs an
// unparsable name would be a sixth case, and Kotlin does not have one.

import SalusDatabase
import SalusModel
import Testing

@testable import FeatureHome

@Suite("TodayDoseAssembler")
struct TodayDoseAssemblerTests {
    /// `TodayDoseAssemblerTest.kt:15`.
    private let today = 20000

    /// `TodayDoseAssemblerTest.kt:54-67`.
    @Test("daily dose appears with PENDING before its time and MISSED after grace")
    func dailyDoseAppearsWithPendingBeforeItsTimeAndMissedAfterGrace() throws {
        let doses = TodayDoseAssembler.assemble(
            medications: [medication()],
            schedules: [schedule(minutes: 480)],
            logs: [],
            today: today,
            nowMinute: 400
        )
        #expect(doses.count == 1)
        #expect(try #require(doses.first).status == .pending)

        let missed = TodayDoseAssembler.assemble(
            medications: [medication()],
            schedules: [schedule(minutes: 480)],
            logs: [],
            today: today,
            nowMinute: 480 + TodayDoseAssembler.graceMinutes + 1
        )
        #expect(missed.count == 1)
        #expect(try #require(missed.first).status == .missed)
    }

    /// `TodayDoseAssemblerTest.kt:69-76` — `>` not `>=`, so the boundary minute is still pending.
    @Test("within the grace window an overdue dose stays PENDING")
    func withinTheGraceWindowAnOverdueDoseStaysPending() throws {
        let doses = TodayDoseAssembler.assemble(
            medications: [medication()],
            schedules: [schedule(minutes: 480)],
            logs: [],
            today: today,
            nowMinute: 480 + 30
        )
        #expect(doses.count == 1)
        #expect(try #require(doses.first).status == .pending)
    }

    /// `TodayDoseAssemblerTest.kt:78-90`. `nowMinute = 700` is past both slots plus the grace, so
    /// the logs are what keep the two doses off `MISSED`.
    @Test("taken and snoozed logs resolve their statuses")
    func takenAndSnoozedLogsResolveTheirStatuses() {
        let doses = TodayDoseAssembler.assemble(
            medications: [medication()],
            schedules: [schedule(id: "sch-1", minutes: 480), schedule(id: "sch-2", minutes: 600)],
            logs: [
                log(scheduleId: "sch-1", minutes: 480, status: .taken),
                log(scheduleId: "sch-2", minutes: 600, status: .pending, snoozedUntil: 123)
            ],
            today: today,
            nowMinute: 700
        )
        #expect(doses.map(\.status) == [.taken, .snoozed])
    }

    /// `TodayDoseAssemblerTest.kt:92-106`.
    @Test("interval schedule skips non-matching days and medication window is respected")
    func intervalScheduleSkipsNonMatchingDaysAndMedicationWindowIsRespected() {
        let offDay = TodayDoseAssembler.assemble(
            medications: [medication()],
            schedules: [schedule(recurrence: .intervalDays, intervalDays: 2, anchor: today - 1)],
            logs: [],
            today: today,
            nowMinute: 0
        )
        #expect(offDay.isEmpty)

        let ended = TodayDoseAssembler.assemble(
            medications: [medication(end: today - 1)],
            schedules: [schedule()],
            logs: [],
            today: today,
            nowMinute: 0
        )
        #expect(ended.isEmpty)
    }

    /// `TodayDoseAssemblerTest.kt:108-119`.
    @Test("output sorted by time then name")
    func outputSortedByTimeThenName() {
        let doses = TodayDoseAssembler.assemble(
            medications: [medication(id: "med-1", name: "B"), medication(id: "med-2", name: "A")],
            schedules: [
                schedule(id: "s1", medicationId: "med-1", minutes: 600),
                schedule(id: "s2", medicationId: "med-2", minutes: 480)
            ],
            logs: [],
            today: today,
            nowMinute: 0
        )
        #expect(doses.map(\.medicationName) == ["A", "B"])
    }

    // MARK: - Fixtures (`TodayDoseAssemblerTest.kt:17-52`)

    private func medication(
        id: String = "med-1",
        name: String = "Aspirin",
        start: Int = 0,
        end: Int? = nil
    ) -> MedicationRecord {
        MedicationRecord(
            id: id,
            profileId: "p",
            name: name,
            form: "TABLET",
            strengthValue: nil,
            strengthUnit: nil,
            colorToken: "primary",
            instructions: nil,
            stockCount: nil,
            stockThreshold: nil,
            startDateEpochDay: start,
            endDateEpochDay: end,
            isActive: true,
            remindersEnabled: true,
            createdAtEpochMs: 0,
            updatedAtEpochMs: 0
        )
    }

    private func schedule(
        id: String = "sch-1",
        medicationId: String = "med-1",
        minutes: Int = 480,
        recurrence: Recurrence = .daily,
        intervalDays: Int? = nil,
        anchor: Int = 0
    ) -> MedicationScheduleRecord {
        MedicationScheduleRecord(
            id: id,
            medicationId: medicationId,
            recurrence: recurrence.rawValue,
            daysOfWeekMask: 0,
            intervalDays: intervalDays,
            anchorDateEpochDay: anchor,
            timeOfDayMinutes: minutes,
            doseAmount: 1.0,
            isActive: true
        )
    }

    private func log(
        scheduleId: String = "sch-1",
        minutes: Int = 480,
        status: IntakeStatus = .taken,
        snoozedUntil: Int64? = nil
    ) -> MedicationIntakeLogRecord {
        MedicationIntakeLogRecord(
            id: "log",
            scheduleId: scheduleId,
            medicationId: "med-1",
            profileId: "p",
            scheduledDateEpochDay: today,
            scheduledMinutes: minutes,
            status: status.rawValue,
            takenAtEpochMs: nil,
            snoozedUntilEpochMs: snoozedUntil,
            doseAmount: 1.0,
            note: nil
        )
    }
}
