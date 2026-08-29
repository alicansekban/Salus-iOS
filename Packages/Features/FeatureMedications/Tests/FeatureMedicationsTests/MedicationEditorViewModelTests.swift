// Ported from `feature/medications/src/test/kotlin/com/alicansekban/salus/feature/medications/
// ui/editor/MedicationEditorViewModelTest.kt` — all six cases, by name, in the Kotlin order.
//
// The mechanical differences are the ones this target has already settled:
// `MainDispatcherRule` has no twin — `@MainActor` on the suite is the whole mechanism;
// Turbine's `state.test { awaitItemWhere { … } }` and `advanceUntilIdle()` both become `waitUntil`,
// a bounded yield loop, because the iOS state is an `@Observable` property and Swift Testing has no
// virtual scheduler; and `advanceUntilIdle()` closing the undo window becomes
// `TestDeletes.closeUndoWindow()`, the gate `PendingDeleteController`'s injected `sleep` waits on.
//
// `IdGenerator { "gen-${nextId++}" }` (`MedicationEditorViewModelTest.kt:47`) has no SAM twin —
// `newId()` is non-mutating — so the counter lives in the small class at the bottom of this file.
// `TestData.swift`'s `FixedIdGenerator` would answer the medication and its schedule the same id,
// which is the one thing this fixture exists to avoid.

import Foundation
import SalusCommon
import SalusModel
import SalusNavigation
import SalusTesting
import Testing

@testable import FeatureMedications

@Suite("MedicationEditorViewModel")
@MainActor
struct MedicationEditorViewModelTests {
    /// `MedicationEditorViewModelTest.kt:44` — the same instant, so `clock.today()` is the same day
    /// on both platforms.
    private let clock = FixedSalusClock(
        now: Date(epochMilliseconds: 1_760_000_000_000),
        timeZone: FixedSalusClock.defaultZone
    )
    private let repository = FakeMedicationRepository()
    private let navigator = FakeNavigator()
    private let scheduler = FakeReminderScheduler()
    private let deletes = TestDeletes()
    private let idGenerator = SequentialIdGenerator()

    /// `MedicationEditorViewModelTest.kt:49-58`.
    private func viewModel(medicationId: String? = nil) -> MedicationEditorViewModel {
        MedicationEditorViewModel(
            medicationId: medicationId,
            repository: repository,
            saveMedication: SaveMedicationUseCase(repository: repository, reminderScheduler: scheduler),
            deleteMedication: DeleteMedicationUseCase(repository: repository, reminderScheduler: scheduler),
            clock: clock,
            idGenerator: idGenerator,
            navigator: navigator.navigator,
            undoableDelete: deletes.undoableDelete
        )
    }

    /// `MedicationEditorViewModelTest.kt:60-69`.
    @Test("new medication starts with today and one default dose time")
    func newMedicationStartsWithTodayAndOneDefaultDoseTime() {
        let state = viewModel().state

        #expect(state.isNew)
        #expect(state.startDateEpochDay == clock.todayEpochDay())
        #expect(state.doseTimes.count == 1)
        #expect(state.doseTimes.first?.minuteOfDay == 8 * 60)
        navigator.stop()
    }

    /// `MedicationEditorViewModelTest.kt:71-91`.
    @Test("existing medication loads fields and schedule rows")
    func existingMedicationLoadsFieldsAndScheduleRows() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(id: "med-9", name: "Iron"),
                schedules: [
                    testSchedule(id: "s1", medicationId: "med-9", timeOfDayMinutes: 540),
                    testSchedule(id: "s2", medicationId: "med-9", timeOfDayMinutes: 1200)
                ]
            )
        ])

        let viewModel = viewModel(medicationId: "med-9")
        await waitUntil("the medication to load") { !viewModel.state.isLoading }

        let loaded = viewModel.state
        #expect(loaded.name == "Iron")
        #expect(loaded.doseTimes.map(\.minuteOfDay) == [540, 1200])
        #expect(loaded.doseTimes.map(\.existingScheduleId) == ["s1", "s2"])
        navigator.stop()
    }

    /// `MedicationEditorViewModelTest.kt:93-107`.
    @Test("save with valid input persists and closes")
    func saveWithValidInputPersistsAndCloses() async throws {
        let viewModel = viewModel()
        viewModel.onEvent(.nameChanged("Vitamin D"))

        viewModel.onEvent(.saveClicked)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }

        #expect(repository.medications.count == 1)
        let saved = try #require(repository.medications.first)
        #expect(saved.medication.name == "Vitamin D")
        #expect(saved.schedules.count == 1)
        #expect(scheduler.syncRequests == 1)
        navigator.stop()
    }

    /// `MedicationEditorViewModelTest.kt:109-118`.
    @Test("save with blank name surfaces the error and does not close")
    func saveWithBlankNameSurfacesTheErrorAndDoesNotClose() async {
        let viewModel = viewModel()

        viewModel.onEvent(.saveClicked)
        await waitUntil("the empty-name error") { viewModel.state.error == .emptyName }

        #expect(repository.medications.isEmpty)
        navigator.stop()
    }

    /// `MedicationEditorViewModelTest.kt:120-130`.
    @Test("days-of-week without a selected day surfaces the error")
    func daysOfWeekWithoutASelectedDaySurfacesTheError() async {
        let viewModel = viewModel()
        viewModel.onEvent(.nameChanged("X"))
        viewModel.onEvent(.recurrenceSelected(.daysOfWeek))

        viewModel.onEvent(.saveClicked)
        await waitUntil("the no-days error") { viewModel.state.error == .noDaysSelected }

        #expect(viewModel.state.error == .noDaysSelected)
        navigator.stop()
    }

    /// `MedicationEditorViewModelTest.kt:132-153`.
    @Test("delete confirms first, then defers the write and closes")
    func deleteConfirmsFirstThenDefersTheWriteAndCloses() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(id: "med-9"),
                schedules: [testSchedule(medicationId: "med-9")]
            )
        ])
        let viewModel = viewModel(medicationId: "med-9")
        await waitUntil("the medication to load") { !viewModel.state.isLoading }

        viewModel.onEvent(.deleteClicked)
        #expect(viewModel.state.showDeleteConfirm)
        #expect(navigator.commandLog.isEmpty)
        #expect(!repository.medications.isEmpty)

        viewModel.onEvent(.deleteConfirmed)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }
        // `MedicationEditorViewModelTest.kt:146` — the write waits for the undo window. The yield
        // drains the cooperative pool first, so a deferred write that was already ready to run gets
        // its turn before the log is read.
        await Task.yield()
        #expect(!repository.medications.isEmpty)

        await deletes.closeUndoWindow()
        await waitUntil("the deferred write to commit") { repository.medications.isEmpty }
        // `MedicationEditorViewModelTest.kt:151` — the delete use case asks the engine to re-sync,
        // so the deleted medication's pending alarms go with it.
        #expect(scheduler.syncRequests == 1)
        navigator.stop()
    }
}

/// The twin of Kotlin's `IdGenerator { "gen-${nextId++}" }`
/// (`MedicationEditorViewModelTest.kt:46-47`): every call answers a fresh, assertable id, so the
/// medication and the schedule the editor builds for it cannot be handed the same one.
///
/// `@unchecked Sendable` for `FakeReminderScheduler`'s reason: the counter is mutable and the lock
/// is what makes the promise true.
private final class SequentialIdGenerator: IdGenerator, @unchecked Sendable {
    private let lock = NSLock()
    private var next = 0

    func newId() -> String {
        lock.withLock {
            defer { next += 1 }
            return "gen-\(next)"
        }
    }
}
