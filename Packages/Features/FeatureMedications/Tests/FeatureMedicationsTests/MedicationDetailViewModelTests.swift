// Ported from `feature/medications/src/test/kotlin/com/alicansekban/salus/feature/medications/
// ui/detail/MedicationDetailViewModelTest.kt` — all eight cases, by name, in the Kotlin order.
//
// The mechanical differences are the ones this target already settled, and no case is re-based:
// Turbine's `state.test { skipItems(1); awaitItem() }` becomes reading `viewModel.state` after
// `waitUntil`, because the iOS state is an `@Observable` property rather than a `StateFlow`;
// `MainDispatcherRule` has no twin — `@MainActor` on the suite is the whole mechanism;
// `advanceUntilIdle()` closing the undo window becomes `TestDeletes.closeUndoWindow()`, the gate
// `PendingDeleteController`'s injected `sleep` waits on; and `navigator.commandLog` is drained on
// the main actor, so the pop is read through `waitUntil` rather than straight after the event
// (`FakeNavigator.swift` records that lag).
//
// One assertion is added rather than ported, and it is the same divergence (b) the appointments
// detail suite carries: Kotlin asserts only that one snackbar was shown, because Android's undo
// snackbar is indefinite. The iOS controller publishes the snackbar that is *up*, so "exactly one"
// is spelled as one being up and nothing coming up behind it when it is taken away.
//
// One whole case is added rather than ported — `history can hold two equal items when two schedules
// share a minute` — by the final review of iOS-M5. It pins the *reachability* half of the view's
// row-identity fix: `MedicationHistorySection` keys its rows by position because the ViewModel can
// legitimately publish two equal `IntakeHistoryItem`s. Kotlin has no twin because Compose's
// `items(list)` is already keyed by index unless a `key` is given.

import Foundation
import SalusCommon
import SalusModel
import SalusNavigation
import SalusTesting
import SalusUI
import Testing

@testable import FeatureMedications

@Suite("MedicationDetailViewModel")
@MainActor
struct MedicationDetailViewModelTests {
    /// `MedicationDetailViewModelTest.kt:43-45` — the same zone and day.
    private static let zone = FixedSalusClock.defaultZone
    private static let today = LocalDate(year: 2026, month: 3, day: 8)
    private static let todayEpoch = today.epochDay

    /// `MedicationDetailViewModelTest.kt:46` — noon, the instant Kotlin's fixture pins.
    private let clock = FixedSalusClock(
        now: LocalDateTime(date: MedicationDetailViewModelTests.today, minuteOfDay: 12 * 60)
            .instant(in: MedicationDetailViewModelTests.zone),
        timeZone: MedicationDetailViewModelTests.zone
    )
    private let repository = FakeMedicationRepository()
    private let navigator = FakeNavigator()
    private let scheduler = FakeReminderScheduler()
    private let deletes = TestDeletes()

    /// `MedicationDetailViewModelTest.kt:52-60`.
    private func viewModel() -> MedicationDetailViewModel {
        MedicationDetailViewModel(
            medicationId: "med-1",
            repository: repository,
            deleteMedication: DeleteMedicationUseCase(repository: repository, reminderScheduler: scheduler),
            navigator: navigator.navigator,
            undoableDelete: deletes.undoableDelete,
            reminderScheduler: scheduler,
            clock: clock
        )
    }

    /// `MedicationDetailViewModelTest.kt:62-77` — the same id shape, so a row is identified by the
    /// triple it is keyed on rather than by a fresh UUID.
    private func log(
        epochDay: Int,
        minuteOfDay: Int,
        medicationId: String = "med-1",
        status: IntakeStatus = .taken
    ) -> IntakeLog {
        testLog(
            id: "\(medicationId)-\(epochDay)-\(minuteOfDay)",
            medicationId: medicationId,
            epochDay: epochDay,
            minuteOfDay: minuteOfDay,
            status: status
        )
    }

    /// `MedicationDetailViewModelTest.kt:80-99`.
    @Test("state carries the medication, its schedules and supply visibility")
    func stateCarriesTheMedicationItsSchedulesAndSupplyVisibility() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(stockCount: 8.0, stockThreshold: 10.0),
                schedules: [testSchedule()]
            )
        ])

        let viewModel = viewModel()

        await waitUntil("the first emission") { !viewModel.state.isLoading }
        let loaded = viewModel.state

        #expect(loaded.isLoading == false)
        #expect(loaded.medication?.name == "Aspirin")
        #expect(loaded.schedules.count == 1)
        #expect(loaded.showSupply)
        #expect(loaded.medication?.isLowOnStock == true)
        navigator.stop()
    }

    /// `MedicationDetailViewModelTest.kt:101-112`.
    @Test("supply is hidden when stock tracking is off")
    func supplyIsHiddenWhenStockTrackingIsOff() async {
        repository.setMedications([
            MedicationWithSchedules(medication: testMedication(stockCount: nil), schedules: [testSchedule()])
        ])

        let viewModel = viewModel()

        await waitUntil("the first emission") { !viewModel.state.isLoading }

        #expect(viewModel.state.showSupply == false)
        navigator.stop()
    }

    /// `MedicationDetailViewModelTest.kt:114-138`.
    @Test("history holds only this medication's logs, newest first")
    func historyHoldsOnlyThisMedicationsLogsNewestFirst() async {
        repository.setMedications([
            MedicationWithSchedules(medication: testMedication(), schedules: [testSchedule()])
        ])
        repository.setLogs([
            log(epochDay: Self.todayEpoch - 1, minuteOfDay: 8 * 60),
            log(epochDay: Self.todayEpoch, minuteOfDay: 20 * 60, status: .missed),
            log(epochDay: Self.todayEpoch, minuteOfDay: 8 * 60),
            // Another medication's log, and one older than the 30-day window.
            log(epochDay: Self.todayEpoch, minuteOfDay: 9 * 60, medicationId: "med-2"),
            log(epochDay: Self.todayEpoch - historyWindowDays - 1, minuteOfDay: 8 * 60)
        ])

        let viewModel = viewModel()

        await waitUntil("the first emission") { !viewModel.state.isLoading }
        let history = viewModel.state.history

        #expect(history.count == 3)
        #expect(history.first?.epochDay == Self.todayEpoch)
        #expect(history.first?.minuteOfDay == 20 * 60)
        #expect(history.first?.status == .missed)
        #expect(history.dropFirst().first?.epochDay == Self.todayEpoch)
        #expect(history.dropFirst().first?.minuteOfDay == 8 * 60)
        #expect(history.last?.epochDay == Self.todayEpoch - 1)
        navigator.stop()
    }

    /// No Kotlin twin — added by the final review of iOS-M5, and the reason
    /// ``MedicationHistorySection`` keys its rows by position instead of by value.
    ///
    /// Two schedules of one medication can share a minute (the editor seeds 08:00 and the add
    /// button re-adds that seed), so when both doses are recorded the two history rows carry the
    /// same day, minute, status and dose amount — they are *equal* values, and a `ForEach` keyed
    /// on the item itself would draw one row for the two of them.
    @Test("history can hold two equal items when two schedules share a minute")
    func historyCanHoldTwoEqualItemsWhenTwoSchedulesShareAMinute() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(),
                schedules: [testSchedule(id: "sch-1"), testSchedule(id: "sch-2")]
            )
        ])
        repository.setLogs([
            testLog(id: "log-a", scheduleId: "sch-1", epochDay: Self.todayEpoch, minuteOfDay: 8 * 60),
            testLog(id: "log-b", scheduleId: "sch-2", epochDay: Self.todayEpoch, minuteOfDay: 8 * 60)
        ])

        let viewModel = viewModel()

        await waitUntil("the first emission") { !viewModel.state.isLoading }
        let history = viewModel.state.history

        #expect(history.count == 2)
        #expect(history.first == history.last)
        navigator.stop()
    }

    /// `MedicationDetailViewModelTest.kt:140-160`.
    @Test("delete asks before it does anything")
    func deleteAsksBeforeItDoesAnything() async {
        repository.setMedications([
            MedicationWithSchedules(medication: testMedication(), schedules: [testSchedule()])
        ])
        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        viewModel.onEvent(.deleteClicked)

        #expect(viewModel.state.showDeleteConfirm)
        #expect(repository.medications.isEmpty == false)
        #expect(navigator.commandLog.isEmpty)

        viewModel.onEvent(.deleteDismissed)

        #expect(viewModel.state.showDeleteConfirm == false)
        #expect(repository.medications.isEmpty == false)
        navigator.stop()
    }

    /// `MedicationDetailViewModelTest.kt:162-181`. The two snackbar assertions are divergence (b).
    @Test("confirming defers the write, closes the screen and offers undo")
    func confirmingDefersTheWriteClosesTheScreenAndOffersUndo() async {
        repository.setMedications([
            MedicationWithSchedules(medication: testMedication(), schedules: [testSchedule()])
        ])
        let viewModel = viewModel()

        viewModel.onEvent(.deleteConfirmed)

        // The row is gone from every list at once, but nothing is written yet.
        #expect(deletes.controller.pendingIds == ["med-1"])
        #expect(repository.medications.isEmpty == false)
        #expect(deletes.lastRequest?.message == MedicationsStrings.deleted)
        await waitUntil("the screen to pop") { navigator.commandLog == [.pop] }

        deletes.snackbar.dismiss()
        #expect(deletes.lastRequest == nil)

        await deletes.closeUndoWindow()
        await waitUntil("the deferred write to commit") { repository.medications.isEmpty }
        // The delete use case asks the engine to re-sync, so the deleted medication's pending
        // alarms go with it (`MedicationDetailViewModelTest.kt:180`).
        #expect(scheduler.syncRequests == 1)
        navigator.stop()
    }

    /// `MedicationDetailViewModelTest.kt:183-197`.
    @Test("undo cancels the deletion the popped screen started")
    func undoCancelsTheDeletionThePoppedScreenStarted() async {
        repository.setMedications([
            MedicationWithSchedules(medication: testMedication(), schedules: [testSchedule()])
        ])
        let viewModel = viewModel()

        viewModel.onEvent(.deleteConfirmed)
        deletes.undoLast()
        await waitUntil("the undo to clear the pending set") { deletes.controller.pendingIds.isEmpty }

        await deletes.closeUndoWindow()

        #expect(repository.medications.isEmpty == false)
        #expect(scheduler.syncRequests == 0)
        navigator.stop()
    }

    /// `MedicationDetailViewModelTest.kt:199-209`.
    @Test("a medication that no longer exists leaves the screen with nothing to show")
    func aMedicationThatNoLongerExistsLeavesTheScreenWithNothingToShow() async {
        let viewModel = viewModel()

        await waitUntil("the first emission") { !viewModel.state.isLoading }
        let loaded = viewModel.state

        #expect(loaded.isLoading == false)
        #expect(loaded.medication == nil)
        #expect(loaded.showSupply == false)
        navigator.stop()
    }

    /// `MedicationDetailViewModelTest.kt:211-226`.
    @Test("toggling reminders writes immediately and requests a sync")
    func togglingRemindersWritesImmediatelyAndRequestsASync() async {
        repository.setMedications([
            MedicationWithSchedules(medication: testMedication(), schedules: [])
        ])
        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        #expect(viewModel.state.medication?.remindersEnabled == true)

        viewModel.onEvent(.remindersToggled(false))

        await waitUntil("the write to be re-observed") {
            viewModel.state.medication?.remindersEnabled == false
        }
        #expect(repository.reminderToggles == [ReminderToggle(medicationId: "med-1", enabled: false)])
        #expect(scheduler.syncRequests == 1)
        navigator.stop()
    }
}
