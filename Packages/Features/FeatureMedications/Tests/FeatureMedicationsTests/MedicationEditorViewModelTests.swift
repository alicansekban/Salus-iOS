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
//
// The last five cases are the post-save reminder warning's, and one of them reads differently from
// its Android twin on purpose: Android's "DEGRADED → pop, no warning" can be spelled with a denied
// full-screen intent, which on iOS is `alarmKitDenied` — a *soft* problem there and here, but iOS
// has only ONE hard problem (`ReminderReadiness.swift`: a denied notification silences the
// pipeline, everything else falls back to it). So the degraded case is a denied AlarmKit on a
// system that has one, and the broken case is always notifications-off.

import Foundation
import SalusCommon
import SalusModel
import SalusNavigation
import SalusReminder
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
    ///
    /// The environment defaults to a healthy device, so every case that predates the post-save
    /// warning still saves and pops.
    private func viewModel(
        medicationId: String? = nil,
        environment: FakeReminderEnvironment = FakeReminderEnvironment(),
        alarmKitSupported: Bool = false
    ) -> MedicationEditorViewModel {
        MedicationEditorViewModel(
            medicationId: medicationId,
            repository: repository,
            saveMedication: SaveMedicationUseCase(repository: repository, reminderScheduler: scheduler),
            deleteMedication: DeleteMedicationUseCase(repository: repository, reminderScheduler: scheduler),
            clock: clock,
            idGenerator: idGenerator,
            navigator: navigator.navigator,
            undoableDelete: deletes.undoableDelete,
            environment: environment,
            alarmKitSupported: alarmKitSupported
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

    // MARK: - The post-save reminder warning

    /// A device where nothing the engine schedules is ever seen keeps the editor open and names
    /// why, rather than closing on a reminder that will never fire. The medication is still saved:
    /// the warning is about the alarm, not about the row.
    @Test("reminders on and a broken device warns instead of closing")
    func remindersOnAndABrokenDeviceWarnsInsteadOfClosing() async {
        let viewModel = viewModel(environment: FakeReminderEnvironment(notifications: false))
        viewModel.onEvent(.nameChanged("Vitamin D"))

        viewModel.onEvent(.saveClicked)
        await waitUntil("the warning") { viewModel.state.reminderWarning != nil }
        // Drains the cooperative pool, so a pop that was already queued is recorded before the
        // negative assertion below reads the log.
        await Task.yield()

        #expect(viewModel.state.reminderWarning == [.notificationsOff])
        #expect(repository.medications.count == 1)
        #expect(navigator.commandLog.isEmpty)
        #expect(viewModel.pendingEffects.isEmpty)
        navigator.stop()
    }

    /// The soft half. A denied AlarmKit on a system that has one is `DEGRADED` — the dose still
    /// posts, time-sensitive and with the alarm sound — so there is nothing to stop the user on.
    @Test("a degraded device closes without a warning")
    func aDegradedDeviceClosesWithoutAWarning() async {
        let viewModel = viewModel(
            environment: FakeReminderEnvironment(alarmKit: false),
            alarmKitSupported: true
        )
        viewModel.onEvent(.nameChanged("Vitamin D"))

        viewModel.onEvent(.saveClicked)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }

        #expect(viewModel.state.reminderWarning == nil)
        navigator.stop()
    }

    /// The "reminders off" half, and the rule behind it: `remindersEnabled` is not an editor field
    /// on either platform, so an as-needed medication — which schedules no clock time and therefore
    /// no dose alarm — is what "reminders off" means here. The device is never even asked.
    @Test("an as-needed medication closes even on a broken device")
    func anAsNeededMedicationClosesEvenOnABrokenDevice() async {
        let environment = FakeReminderEnvironment(notifications: false)
        let viewModel = viewModel(environment: environment)
        viewModel.onEvent(.nameChanged("Painkiller"))
        viewModel.onEvent(.recurrenceSelected(.asNeeded))

        viewModel.onEvent(.saveClicked)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }

        #expect(viewModel.state.reminderWarning == nil)
        #expect(environment.readCount == 0)
        navigator.stop()
    }

    /// Fix asks the shell for Reminder health and pops nothing: the shell does the pop and the push
    /// together, because a pop from here would tear down the Route that delivers the effect. Once
    /// each, however many times the answer is delivered.
    @Test("Fix asks for Reminder health once and leaves the pop to the shell")
    func fixAsksForReminderHealthOnceAndLeavesThePopToTheShell() async {
        let viewModel = viewModel(environment: FakeReminderEnvironment(notifications: false))
        viewModel.onEvent(.nameChanged("Vitamin D"))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the warning") { viewModel.state.reminderWarning != nil }

        viewModel.onEvent(.reminderWarningFixClicked)
        // The alert's binding reports the system-driven dismissal that follows *either* button, so
        // this second event is what the screen really sends. A warning is answered exactly once,
        // which is what keeps it from popping the screen the shell is already popping.
        viewModel.onEvent(.reminderWarningDismissed)
        // Drains the cooperative pool, so a pop queued by either event is recorded before the
        // negative assertion below reads the log.
        await Task.yield()

        #expect(navigator.commandLog.isEmpty)
        #expect(viewModel.state.reminderWarning == nil)
        #expect(viewModel.consumeEffects() == [.openReminderHealth])
        #expect(viewModel.pendingEffects.isEmpty)
        navigator.stop()
    }

    /// Not now closes the editor and changes nothing else.
    @Test("Not now pops and asks for nothing")
    func notNowPopsAndAsksForNothing() async {
        let viewModel = viewModel(environment: FakeReminderEnvironment(notifications: false))
        viewModel.onEvent(.nameChanged("Vitamin D"))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the warning") { viewModel.state.reminderWarning != nil }

        viewModel.onEvent(.reminderWarningDismissed)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }

        #expect(viewModel.state.reminderWarning == nil)
        #expect(viewModel.pendingEffects.isEmpty)
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
