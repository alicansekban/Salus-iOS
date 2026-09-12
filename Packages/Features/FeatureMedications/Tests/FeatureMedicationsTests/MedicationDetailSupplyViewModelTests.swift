// The M15 half of `MedicationDetailViewModelTest.kt` — `daysOfSupply` (`:88-226`) and the dose the
// screen offers (`:228-293`), ported case for case.
//
// A second suite rather than nine more cases in `MedicationDetailViewModelTests`: that type was
// already at SwiftLint's 300-line body limit, and these nine share no fixture with the delete and
// history cases beyond the graph every suite in this target builds the same way. The fixture below
// is that graph, spelled once more rather than reached across files — a `private let` on one suite
// is not visible to another, and making it visible would couple two tables that are free to drift.

import Foundation
import SalusCommon
import SalusModel
import SalusNavigation
import SalusTesting
import SalusUI
import Testing

@testable import FeatureMedications

@Suite("MedicationDetailViewModel — supply and the dose on offer")
@MainActor
struct MedicationDetailSupplyViewModelTests {
    /// `MedicationDetailViewModelTest.kt:43-46` — the same zone, day and noon instant.
    private static let zone = FixedSalusClock.defaultZone
    private static let today = LocalDate(year: 2026, month: 3, day: 8)
    private static let todayEpoch = today.epochDay

    private let clock = FixedSalusClock(
        now: LocalDateTime(date: MedicationDetailSupplyViewModelTests.today, minuteOfDay: 12 * 60)
            .instant(in: MedicationDetailSupplyViewModelTests.zone),
        timeZone: MedicationDetailSupplyViewModelTests.zone
    )
    private let repository = FakeMedicationRepository()
    private let navigator = FakeNavigator()
    private let scheduler = FakeReminderScheduler()
    private let deletes = TestDeletes()

    /// `MedicationDetailViewModelTest.kt:51-52` — the next calendar day, 09:00, past the 08:00 dose
    /// the screen is built around.
    private static let tomorrow = LocalDate(year: 2026, month: 3, day: 9)
    private var tomorrowMorning: Date {
        LocalDateTime(date: Self.tomorrow, minuteOfDay: 9 * 60).instant(in: Self.zone)
    }

    /// `MedicationDetailViewModelTest.kt:52-60`.
    private func viewModel() -> MedicationDetailViewModel {
        MedicationDetailViewModel(
            medicationId: "med-1",
            repository: repository,
            deleteMedication: DeleteMedicationUseCase(repository: repository, reminderScheduler: scheduler),
            markDoseTaken: MarkDoseTakenUseCase(
                repository: repository,
                clock: clock,
                idGenerator: FixedIdGenerator(id: "log-id")
            ),
            navigator: navigator.navigator,
            undoableDelete: deletes.undoableDelete,
            reminderScheduler: scheduler,
            clock: clock
        )
    }

    /// `MedicationDetailViewModelTest.kt:88-103`.
    @Test("days of supply divides the remaining count by what one day consumes")
    func daysOfSupplyDividesTheRemainingCountByWhatOneDayConsumes() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(stockCount: 7.0),
                schedules: [testSchedule(doseAmount: 2.0)]
            )
        ])

        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        // 7 left, 2 leave the box each day: three whole days, never a rounded-up fourth.
        #expect(viewModel.state.daysOfSupply == 3)
        navigator.stop()
    }

    /// `MedicationDetailViewModelTest.kt:105-123`.
    @Test("days of supply sums every schedule of the day")
    func daysOfSupplySumsEveryScheduleOfTheDay() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(stockCount: 10.0),
                schedules: [
                    testSchedule(id: "sch-1", timeOfDayMinutes: 8 * 60, doseAmount: 1.0),
                    testSchedule(id: "sch-2", timeOfDayMinutes: 20 * 60, doseAmount: 1.5)
                ]
            )
        ])

        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        // 2.5 a day out of 10 is four whole days.
        #expect(viewModel.state.daysOfSupply == 4)
        navigator.stop()
    }

    /// `MedicationDetailViewModelTest.kt:125-145`.
    @Test("days of supply spreads an every-third-day schedule over its interval")
    func daysOfSupplySpreadsAnEveryThirdDayScheduleOverItsInterval() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(stockCount: 9.0),
                schedules: [testSchedule(recurrence: .intervalDays, intervalDays: 3, doseAmount: 3.0)]
            )
        ])

        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        // Three units every third day is one unit a day on average: nine days, not three.
        #expect(viewModel.state.daysOfSupply == 9)
        navigator.stop()
    }

    /// `MedicationDetailViewModelTest.kt:147-169`.
    @Test("days of supply spreads a two-weekday schedule over the week")
    func daysOfSupplySpreadsATwoWeekdayScheduleOverTheWeek() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(stockCount: 2.0),
                schedules: [
                    testSchedule(
                        recurrence: .daysOfWeek,
                        // Monday and Wednesday.
                        daysOfWeekMask: 0b0000101,
                        doseAmount: 1.0
                    )
                ]
            )
        ])

        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        // Two of seven days consume one unit, so two units last a whole week.
        #expect(viewModel.state.daysOfSupply == 7)
        navigator.stop()
    }

    /// `MedicationDetailViewModelTest.kt:171-196`.
    @Test("days of supply sums the daily average of every schedule")
    func daysOfSupplySumsTheDailyAverageOfEverySchedule() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(stockCount: 10.0),
                schedules: [
                    testSchedule(id: "sch-daily", doseAmount: 1.0),
                    testSchedule(
                        id: "sch-every-other-day",
                        recurrence: .intervalDays,
                        intervalDays: 2,
                        timeOfDayMinutes: 20 * 60,
                        doseAmount: 1.0
                    )
                ]
            )
        ])

        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        // 1 a day plus 0.5 a day is 1.5: ten units cover six whole days.
        #expect(viewModel.state.daysOfSupply == 6)
        navigator.stop()
    }

    /// `MedicationDetailViewModelTest.kt:198-209`.
    @Test("days of supply is absent when stock is not tracked")
    func daysOfSupplyIsAbsentWhenStockIsNotTracked() async {
        repository.setMedications([
            MedicationWithSchedules(medication: testMedication(stockCount: nil), schedules: [testSchedule()])
        ])

        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        #expect(viewModel.state.daysOfSupply == nil)
        navigator.stop()
    }

    /// `MedicationDetailViewModelTest.kt:211-226`.
    @Test("days of supply is absent when no dose leaves the box on a given day")
    func daysOfSupplyIsAbsentWhenNoDoseLeavesTheBoxOnAGivenDay() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(stockCount: 12.0),
                // As-needed doses have no daily rate to divide by.
                schedules: [testSchedule(recurrence: .asNeeded, timeOfDayMinutes: 0)]
            )
        ])

        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        #expect(viewModel.state.daysOfSupply == nil)
        navigator.stop()
    }

    /// `MedicationDetailViewModelTest.kt:228-251`.
    @Test("a dose whose time has passed today is offered for recording")
    func aDoseWhoseTimeHasPassedTodayIsOfferedForRecording() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(startDateEpochDay: Self.todayEpoch, stockCount: 10.0),
                // 08:00, and the clock says noon.
                schedules: [testSchedule(anchorDateEpochDay: Self.todayEpoch)]
            )
        ])
        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        guard let due = viewModel.state.pendingDose else {
            Issue.record("the screen offered no dose to record")
            return
        }
        #expect(due.minuteOfDay == 8 * 60)

        viewModel.onEvent(.takeDoseClicked(due))
        await waitUntil("the dose to be written") { repository.logs.count == 1 }

        #expect(repository.logs.first?.status == .taken)
        #expect(repository.stockDecrements == [StockDecrement(medicationId: "med-1", amount: 1.0)])
        navigator.stop()
    }

    /// `MedicationDetailViewModelTest.kt:253-293`.
    @Test("a dose the screen built yesterday is never recorded against yesterday")
    func aDoseTheScreenBuiltYesterdayIsNeverRecordedAgainstYesterday() async {
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
        guard let staleDose = viewModel.state.pendingDose else {
            Issue.record("the screen offered no dose to record")
            return
        }
        #expect(staleDose.epochDay == Self.todayEpoch)

        // The screen can sit open across midnight; recording the dose it drew then must not write
        // an intake row dated yesterday.
        clock.advanceTo(tomorrowMorning)
        viewModel.onEvent(.takeDoseClicked(staleDose))

        // Nothing to wait for, so the fake is settled first: a yield drains whatever the event
        // could have enqueued, and only then is "still empty" a fact rather than a race.
        await Task.yield()
        #expect(repository.logs.isEmpty)
        #expect(repository.stockDecrements.isEmpty)

        // The refusal re-derives the day: the header date and the offered dose both move.
        await waitUntil("the day to roll over") { viewModel.state.todayEpochDay == Self.todayEpoch + 1 }
        guard let freshDose = viewModel.state.pendingDose else {
            Issue.record("the rolled-over screen offered no dose to record")
            return
        }
        #expect(freshDose.epochDay == Self.todayEpoch + 1)

        viewModel.onEvent(.takeDoseClicked(freshDose))
        await waitUntil("the dose to be written") { repository.logs.count == 1 }

        #expect(repository.logs.first?.epochDay == Self.todayEpoch + 1)
        #expect(repository.logs.first?.status == .taken)
        navigator.stop()
    }
}
