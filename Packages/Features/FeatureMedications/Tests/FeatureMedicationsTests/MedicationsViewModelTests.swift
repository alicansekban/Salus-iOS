// Ported from `feature/medications/src/test/kotlin/com/alicansekban/salus/feature/medications/
// ui/list/MedicationsViewModelTest.kt` — all six cases.
//
// Four of the six names are Kotlin's verbatim. The other two — `MedicationsViewModelTest.kt:47`
// and `:81` — are renamed, and the rename is the visible half of decision 1
// (`RecordedDoseRatio.swift:1-13`): Android divides TAKEN doses by the occurrences its generator
// expands, this divides TAKEN by RECORDED, so the number under test is a different one and its test
// must not keep saying otherwise. The two new names are
//
//   `state carries medications with the recorded-dose share over the last seven days`
//   `medication without any recorded dose yet has nil share`
//
// and the two Kotlin names they replace are deliberately not repeated here: both spell a word this
// repo's copy scanner bans on sight (`CLAUDE.md`, the banned-vocabulary rule), which is the whole
// reason the rename exists.
//
// The first case's fixture is re-based with it. Kotlin seeds 4 TAKEN logs against 7 doses the
// generator expands and asserts 57 (4/7); here the denominator is what was recorded, so the same
// 57 is reached by seeding all 7 days — 4 recorded as taken, 3 recorded as skipped. Same assertion,
// same arithmetic, over the base this port actually computes.
//
// Three mechanical differences from the Kotlin, all already settled elsewhere in this port:
// Turbine's `state.test { awaitItemWhere { … } }` becomes reading `viewModel.state` after
// `waitUntil`, because the iOS state is an `@Observable` property rather than a `StateFlow`;
// `MainDispatcherRule` has no twin — `@MainActor` on the suite is the whole mechanism; and
// `advanceUntilIdle()` closing the undo window becomes `TestDeletes.closeUndoWindow()`, the gate
// that stands in for `runTest`'s virtual scheduler.

import Foundation
import SalusCommon
import SalusModel
import SalusTesting
import Testing

@testable import FeatureMedications

@Suite("MedicationsViewModel")
@MainActor
struct MedicationsViewModelTests {
    /// `MedicationsViewModelTest.kt:39-41` — the same zone and day.
    private static let zone = FixedSalusClock.defaultZone
    private static let today = LocalDate(year: 2026, month: 3, day: 8)
    private static let todayEpoch = today.epochDay

    /// `MedicationsViewModelTest.kt:44` — noon, so the Kotlin fixture's "this morning's 08:00 dose
    /// is already expected" holds. Nothing here reads the minute any more (the share is over what
    /// was recorded, not over what a generator expands), but the instant stays Kotlin's so the two
    /// tables describe the same day.
    private let clock = FixedSalusClock(
        now: LocalDateTime(date: MedicationsViewModelTests.today, minuteOfDay: 12 * 60)
            .instant(in: MedicationsViewModelTests.zone),
        timeZone: MedicationsViewModelTests.zone
    )
    private let repository = FakeMedicationRepository()
    private let scheduler = FakeReminderScheduler()
    private let deletes = TestDeletes()

    /// `MedicationsViewModelTest.kt:172-178`.
    private func viewModel() -> MedicationsViewModel {
        MedicationsViewModel(
            repository: repository,
            pendingDeletes: deletes.controller,
            deleteMedication: DeleteMedicationUseCase(repository: repository, reminderScheduler: scheduler),
            undoableDelete: deletes.undoableDelete,
            clock: clock
        )
    }

    /// `MedicationsViewModelTest.kt:180-183`.
    private func singleMedication() -> MedicationWithSchedules {
        MedicationWithSchedules(
            medication: testMedication(startDateEpochDay: Self.todayEpoch - 6),
            schedules: [testSchedule(anchorDateEpochDay: Self.todayEpoch - 6)]
        )
    }

    /// `MedicationsViewModelTest.kt:47-79`, renamed and re-based — see the file header.
    @Test("state carries medications with the recorded-dose share over the last seven days")
    func stateCarriesMedicationsWithTheRecordedDoseShareOverTheLastSevenDays() async {
        repository.setMedications([singleMedication()])
        // 7 recorded doses across the window; 4 of them recorded as taken.
        repository.setLogs((0 ..< 7).map { index in
            testLog(
                id: "log-\(index)",
                epochDay: Self.todayEpoch - 6 + index,
                status: index < 4 ? .taken : .skipped
            )
        })

        let viewModel = viewModel()

        await waitUntil("the first emission") { !viewModel.state.isLoading }
        let item = viewModel.state.medications.first

        #expect(viewModel.state.medications.count == 1)
        #expect(item?.medication.name == "Aspirin")
        #expect(item?.recordedDosePercent == 57) // 4/7 ≈ 57%
    }

    /// `MedicationsViewModelTest.kt:81-96`, renamed — see the file header. Kotlin's medication
    /// starts tomorrow, so nothing was expected of it; here nothing was *recorded* for it, which is
    /// what leaves the share absent. The fixture is Kotlin's either way.
    @Test("medication without any recorded dose yet has nil share")
    func medicationWithoutAnyRecordedDoseYetHasNilShare() async {
        repository.setMedications([
            MedicationWithSchedules(
                medication: testMedication(startDateEpochDay: Self.todayEpoch + 1),
                schedules: [testSchedule(anchorDateEpochDay: Self.todayEpoch + 1)]
            )
        ])

        let viewModel = viewModel()

        await waitUntil("the first emission") { !viewModel.state.isLoading }

        #expect(viewModel.state.medications.count == 1)
        #expect(viewModel.state.medications.first?.recordedDosePercent == nil)
    }

    /// `MedicationsViewModelTest.kt:98-107`.
    @Test("empty repository yields empty non-loading state")
    func emptyRepositoryYieldsEmptyNonLoadingState() async {
        let viewModel = viewModel()

        await waitUntil("the first emission") { !viewModel.state.isLoading }

        #expect(viewModel.state.medications.isEmpty)
    }

    /// `MedicationsViewModelTest.kt:108-124`.
    @Test("delete request asks for confirmation and dismissing it deletes nothing")
    func deleteRequestAsksForConfirmationAndDismissingItDeletesNothing() async {
        repository.setMedications([singleMedication()])
        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        viewModel.onEvent(.deleteRequested("med-1"))
        #expect(viewModel.state.pendingDelete?.name == "Aspirin")

        viewModel.onEvent(.deleteDismissed)
        #expect(viewModel.state.pendingDelete == nil)

        // `MedicationsViewModelTest.kt:122-123` — nothing was scheduled and nothing was offered.
        #expect(deletes.controller.pendingIds.isEmpty)
        #expect(deletes.lastRequest == nil)
    }

    /// `MedicationsViewModelTest.kt:126-148`.
    @Test("confirmed delete hides the row at once and writes when the undo window closes")
    func confirmedDeleteHidesTheRowAtOnceAndWritesWhenTheUndoWindowCloses() async {
        repository.setMedications([singleMedication()])
        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        viewModel.onEvent(.deleteRequested("med-1"))
        viewModel.onEvent(.deleteConfirmed)
        await waitUntil("the row to go and the dialog to close") {
            viewModel.state.medications.isEmpty && viewModel.state.pendingDelete == nil
        }

        // The row is gone, but nothing is written until the window closes.
        #expect(repository.medications.count == 1)
        // `MedicationsViewModelTest.kt:140` — `assertEquals(1, deletes.snackbar.shown.size)`, in the
        // shape `AppointmentsViewModelTests` settled on: the iOS controller publishes the snackbar
        // that is up rather than a log of every request, so "exactly one" is spelled as one being up
        // and nothing coming up behind it when it is taken away.
        #expect(deletes.lastRequest?.message == MedicationsStrings.deleted)
        deletes.snackbar.dismiss()
        #expect(deletes.lastRequest == nil)

        await deletes.closeUndoWindow()
        await waitUntil("the deferred write to commit") { repository.medications.isEmpty }
        // `MedicationsViewModelTest.kt:144` — the delete use case asks the engine to re-sync, so
        // the deleted medication's pending alarms go with it.
        #expect(scheduler.syncRequests == 1)
    }

    /// `MedicationsViewModelTest.kt:149-168`.
    @Test("undo within the window brings the row back without a write")
    func undoWithinTheWindowBringsTheRowBackWithoutAWrite() async {
        repository.setMedications([singleMedication()])
        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        viewModel.onEvent(.deleteRequested("med-1"))
        viewModel.onEvent(.deleteConfirmed)
        await waitUntil("the row to go") { viewModel.state.medications.isEmpty }

        deletes.undoLast()
        await waitUntil("the row to come back") { viewModel.state.medications.count == 1 }

        await deletes.closeUndoWindow()
        #expect(repository.medications.count == 1)
        #expect(scheduler.syncRequests == 0)
    }
}
