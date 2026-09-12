// The M15 half of `MedicationsViewModelTest.kt` (`:199-425`) — what the day summary puts on each
// card, what the header's "next dose" tile reads, and the two cases that cross midnight.
//
// A second suite rather than nine more cases in `MedicationsViewModelTests`: that type was already
// at SwiftLint's 300-line body limit, and these nine share no fixture with the delete cases beyond
// the graph every suite in this target builds the same way. The fixture below is that graph,
// spelled once more rather than reached across files — a `private let` on one suite is not visible
// to another, and making it visible would couple two tables that are free to drift.
//
// **THE CASES THAT MATTER ARE THE TWO THAT MOVE THE CLOCK.** A tab root lives for the whole app
// session, so this view model outlives midnight; the dose a card offers is what "Hemen Al" writes
// into a health record, and a stale day would date that record to yesterday. Both cases advance the
// fake clock and assert on what the state does next — which is the only way to see the per-emission
// clock read at all.

import Foundation
import SalusCommon
import SalusModel
import SalusTesting
import Testing

@testable import FeatureMedications

@Suite("MedicationsViewModel — today's doses")
@MainActor
struct MedicationsDaySummaryViewModelTests {
    /// `MedicationsViewModelTest.kt:39-44` — the same zone, day and noon instant.
    private static let zone = FixedSalusClock.defaultZone
    private static let today = LocalDate(year: 2026, month: 3, day: 8)
    private static let todayEpoch = today.epochDay

    private let clock = FixedSalusClock(
        now: LocalDateTime(date: MedicationsDaySummaryViewModelTests.today, minuteOfDay: 12 * 60)
            .instant(in: MedicationsDaySummaryViewModelTests.zone),
        timeZone: MedicationsDaySummaryViewModelTests.zone
    )
    private let repository = FakeMedicationRepository()
    private let scheduler = FakeReminderScheduler()
    private let deletes = TestDeletes()

    /// `MedicationsViewModelTest.kt:49-50` — the next calendar day, 09:00, past the 08:00 dose the
    /// cards are built around.
    private static let tomorrow = LocalDate(year: 2026, month: 3, day: 9)
    private var tomorrowMorning: Date {
        LocalDateTime(date: Self.tomorrow, minuteOfDay: 9 * 60).instant(in: Self.zone)
    }

    /// `MedicationsViewModelTest.kt:172-178`.
    private func viewModel() -> MedicationsViewModel {
        MedicationsViewModel(
            repository: repository,
            pendingDeletes: deletes.controller,
            deleteMedication: DeleteMedicationUseCase(repository: repository, reminderScheduler: scheduler),
            markDoseTaken: MarkDoseTakenUseCase(
                repository: repository,
                clock: clock,
                idGenerator: FixedIdGenerator(id: "log-id")
            ),
            undoableDelete: deletes.undoableDelete,
            clock: clock
        )
    }

    /// `MedicationsViewModelTest.kt:199-230`.
    @Test("next dose is the earliest dose of today that has no record yet")
    func nextDoseIsTheEarliestDoseOfTodayThatHasNoRecordYet() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(id: "med-1", startDateEpochDay: Self.todayEpoch),
                schedules: [
                    testSchedule(
                        id: "sch-evening",
                        medicationId: "med-1",
                        anchorDateEpochDay: Self.todayEpoch,
                        timeOfDayMinutes: 21 * 60
                    )
                ]
            ),
            MedicationWithSchedules(
                medication: testMedication(id: "med-2", name: "B12", startDateEpochDay: Self.todayEpoch),
                schedules: [
                    testSchedule(
                        id: "sch-morning",
                        medicationId: "med-2",
                        anchorDateEpochDay: Self.todayEpoch,
                        timeOfDayMinutes: 9 * 60
                    )
                ]
            )
        ])

        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        #expect(viewModel.state.nextDoseMinuteOfDay == 9 * 60)
    }

    /// `MedicationsViewModelTest.kt:232-249`.
    @Test("a dose already recorded today is not the next one")
    func aDoseAlreadyRecordedTodayIsNotTheNextOne() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(startDateEpochDay: Self.todayEpoch),
                schedules: [testSchedule(anchorDateEpochDay: Self.todayEpoch)]
            )
        ])
        repository.setLogs([testLog(id: "today", epochDay: Self.todayEpoch, status: .taken)])

        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        #expect(viewModel.state.nextDoseMinuteOfDay == nil)
        #expect(viewModel.state.medications.first?.dayStatus == .taken)
        #expect(viewModel.state.medications.first?.dueDose == nil)
    }

    /// `MedicationsViewModelTest.kt:251-272`.
    @Test("an as-needed medication has no next dose and says so on its card")
    func anAsNeededMedicationHasNoNextDoseAndSaysSoOnItsCard() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(startDateEpochDay: Self.todayEpoch),
                schedules: [
                    testSchedule(
                        recurrence: .asNeeded,
                        anchorDateEpochDay: Self.todayEpoch,
                        timeOfDayMinutes: 0
                    )
                ]
            )
        ])

        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        #expect(viewModel.state.nextDoseMinuteOfDay == nil)
        #expect(viewModel.state.medications.first?.dayStatus == .asNeeded)
    }

    /// `MedicationsViewModelTest.kt:274-290`.
    @Test("a dose whose time has passed with no record is offered for recording")
    func aDoseWhoseTimeHasPassedWithNoRecordIsOfferedForRecording() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(startDateEpochDay: Self.todayEpoch),
                // 08:00, and the clock says noon.
                schedules: [testSchedule(anchorDateEpochDay: Self.todayEpoch)]
            )
        ])

        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }
        let item = viewModel.state.medications.first

        #expect(item?.dayStatus == .pending)
        #expect(item?.dueDose?.minuteOfDay == 8 * 60)
        #expect(item?.dueDose?.scheduleId == "sch-1")
    }

    /// `MedicationsViewModelTest.kt:292-306`.
    @Test("a dose still ahead of the clock is next but not yet offered for recording")
    func aDoseStillAheadOfTheClockIsNextButNotYetOfferedForRecording() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(startDateEpochDay: Self.todayEpoch),
                schedules: [testSchedule(anchorDateEpochDay: Self.todayEpoch, timeOfDayMinutes: 21 * 60)]
            )
        ])

        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        #expect(viewModel.state.nextDoseMinuteOfDay == 21 * 60)
        #expect(viewModel.state.medications.first?.dueDose == nil)
    }

    /// `MedicationsViewModelTest.kt:308-334`.
    @Test("the last dose of the day being skipped is what the card reports")
    func theLastDoseOfTheDayBeingSkippedIsWhatTheCardReports() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(startDateEpochDay: Self.todayEpoch),
                schedules: [
                    testSchedule(id: "sch-1", anchorDateEpochDay: Self.todayEpoch, timeOfDayMinutes: 8 * 60),
                    testSchedule(id: "sch-2", anchorDateEpochDay: Self.todayEpoch, timeOfDayMinutes: 11 * 60)
                ]
            )
        ])
        repository.setLogs([
            testLog(id: "morning", epochDay: Self.todayEpoch, status: .taken),
            testLog(
                id: "noon",
                scheduleId: "sch-2",
                epochDay: Self.todayEpoch,
                minuteOfDay: 11 * 60,
                status: .skipped
            )
        ])

        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        #expect(viewModel.state.medications.first?.dayStatus == .skipped)
        #expect(viewModel.state.nextDoseMinuteOfDay == nil)
    }

    /// `MedicationsViewModelTest.kt:336-355`.
    @Test("recording a due dose from the list goes through the shared dose path")
    func recordingADueDoseFromTheListGoesThroughTheSharedDosePath() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(startDateEpochDay: Self.todayEpoch, stockCount: 10.0),
                schedules: [testSchedule(anchorDateEpochDay: Self.todayEpoch)]
            )
        ])
        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        guard let due = viewModel.state.medications.first?.dueDose else {
            Issue.record("the card offered no dose to record")
            return
        }
        viewModel.onEvent(.takeDoseClicked(due))

        await waitUntil("the dose to be written") { repository.logs.count == 1 }
        #expect(repository.logs.first?.status == .taken)
        #expect(repository.stockDecrements == [StockDecrement(medicationId: "med-1", amount: 1.0)])
    }

    /// `MedicationsViewModelTest.kt:357-397`.
    @Test("a dose the list built yesterday is never recorded against yesterday")
    func aDoseTheListBuiltYesterdayIsNeverRecordedAgainstYesterday() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(startDateEpochDay: Self.todayEpoch, stockCount: 10.0),
                // 08:00 every day, so both days carry the same slot.
                schedules: [testSchedule(anchorDateEpochDay: Self.todayEpoch)]
            )
        ])
        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        #expect(viewModel.state.todayEpochDay == Self.todayEpoch)
        guard let staleDose = viewModel.state.medications.first?.dueDose else {
            Issue.record("the card offered no dose to record")
            return
        }
        #expect(staleDose.epochDay == Self.todayEpoch)

        // The tab root lives for the whole app session, so the card on screen can outlive midnight.
        // Recording it now must not write a health record dated yesterday.
        clock.advanceTo(tomorrowMorning)
        viewModel.onEvent(.takeDoseClicked(staleDose))

        // Nothing to wait for, so the fake is settled first: a yield drains whatever the event
        // could have enqueued, and only then is "still empty" a fact rather than a race.
        await Task.yield()
        #expect(repository.logs.isEmpty)
        #expect(repository.stockDecrements.isEmpty)

        // The refusal re-derives the day instead: the overline date and the offered dose both move
        // to the day the clock is actually in.
        await waitUntil("the day to roll over") { viewModel.state.todayEpochDay == Self.todayEpoch + 1 }
        guard let freshDose = viewModel.state.medications.first?.dueDose else {
            Issue.record("the rolled-over card offered no dose to record")
            return
        }
        #expect(freshDose.epochDay == Self.todayEpoch + 1)

        viewModel.onEvent(.takeDoseClicked(freshDose))
        await waitUntil("the dose to be written") { repository.logs.count == 1 }

        #expect(repository.logs.first?.epochDay == Self.todayEpoch + 1)
        #expect(repository.logs.first?.status == .taken)
    }

    /// `MedicationsViewModelTest.kt:399-425`.
    @Test("the recorded-dose window follows the day, not the construction date")
    func theRecordedDoseWindowFollowsTheDayNotTheConstructionDate() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(startDateEpochDay: Self.todayEpoch - 6),
                schedules: [testSchedule(anchorDateEpochDay: Self.todayEpoch - 6)]
            )
        ])
        repository.setLogs([
            // Day -6 is inside the window today and one day outside it tomorrow.
            testLog(id: "oldest", epochDay: Self.todayEpoch - 6, status: .skipped),
            testLog(id: "today", epochDay: Self.todayEpoch, status: .taken)
        ])
        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        #expect(viewModel.state.medications.first?.recordedDosePercent == 50)

        clock.advanceTo(tomorrowMorning)
        // Any emission re-derives the window; a log written tomorrow is one.
        repository.setLogs(repository.logs + [
            testLog(id: "tomorrow", epochDay: Self.todayEpoch + 1, status: .taken)
        ])

        await waitUntil("the day to roll over") { viewModel.state.todayEpochDay == Self.todayEpoch + 1 }
        // The skipped day fell out of the seven-day window, the new day is inside it.
        #expect(viewModel.state.medications.first?.recordedDosePercent == 100)
    }
}
