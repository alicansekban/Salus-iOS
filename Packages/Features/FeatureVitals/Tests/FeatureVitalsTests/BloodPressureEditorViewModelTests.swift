// Ported 1:1 from `feature/vitals/src/test/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/BloodPressureEditorViewModelTest.kt` — the six cases, in the Kotlin order, with the
// Kotlin inputs and expectations.
//
// `advanceUntilIdle()` becomes `waitUntil`, for the reason `WeightEditorViewModelTests` records:
// the ViewModel's work is on the main actor's cooperative queue rather than on a virtual
// scheduler, and no test here waits on wall-clock time.

import Foundation
import SalusCommon
import SalusNavigation
import SalusTesting
import Testing

@testable import FeatureVitals

@Suite("BloodPressureEditorViewModel")
@MainActor
struct BloodPressureEditorViewModelTests {
    /// `BloodPressureEditorViewModelTest.kt:33-35`.
    private static let now = Date(timeIntervalSince1970: 1_755_000_000)
    private static let zone = FixedSalusClock.defaultZone

    private let clock = FixedSalusClock(
        now: BloodPressureEditorViewModelTests.now,
        timeZone: BloodPressureEditorViewModelTests.zone
    )
    private let repository = FakeVitalsRepository()
    private let navigator = FakeNavigator()
    private let deletes = TestDeletes()

    /// `BloodPressureEditorViewModelTest.kt:40-48`.
    private func viewModel(entryId: String? = nil) -> BloodPressureEditorViewModel {
        BloodPressureEditorViewModel(
            entryId: entryId,
            repository: repository,
            saveBloodPressureEntry: SaveBloodPressureEntryUseCase(
                repository: repository,
                idGenerator: FixedIdGenerator(id: "new-id")
            ),
            clock: clock,
            navigator: navigator.navigator,
            undoableDelete: deletes.undoableDelete
        )
    }

    /// `BloodPressureEditorViewModelTest.kt:50-66`.
    @Test("saving valid values stores entry and closes")
    func savingValidValuesStoresEntryAndCloses() async throws {
        let viewModel = viewModel()

        viewModel.onEvent(.systolicChanged("120"))
        viewModel.onEvent(.diastolicChanged("80"))
        viewModel.onEvent(.pulseChanged("62"))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }

        let saved = try #require(repository.currentBloodPressure().first)
        #expect(repository.currentBloodPressure().count == 1)
        #expect(saved.id == "new-id")
        #expect(saved.systolic == 120.0)
        #expect(saved.diastolic == 80.0)
        #expect(saved.pulse == 62.0)
        navigator.stop()
    }

    /// `BloodPressureEditorViewModelTest.kt:68-79`.
    @Test("blank pulse saves entry without pulse")
    func blankPulseSavesEntryWithoutPulse() async throws {
        let viewModel = viewModel()

        viewModel.onEvent(.systolicChanged("120"))
        viewModel.onEvent(.diastolicChanged("80"))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }

        let saved = try #require(repository.currentBloodPressure().first)
        #expect(repository.currentBloodPressure().count == 1)
        #expect(saved.pulse == nil)
        navigator.stop()
    }

    /// `BloodPressureEditorViewModelTest.kt:81-92`.
    @Test("invalid systolic shows error and saves nothing")
    func invalidSystolicShowsErrorAndSavesNothing() async {
        let viewModel = viewModel()

        viewModel.onEvent(.systolicChanged("300"))
        viewModel.onEvent(.diastolicChanged("80"))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the rejection") { viewModel.state.error != nil }

        #expect(viewModel.state.error == .invalidSystolic)
        #expect(repository.currentBloodPressure().isEmpty)
        #expect(navigator.commandLog.isEmpty)
        navigator.stop()
    }

    /// `BloodPressureEditorViewModelTest.kt:94-107`.
    @Test("systolic not above diastolic maps to its own error and typing clears it")
    func systolicNotAboveDiastolicMapsToItsOwnErrorAndTypingClearsIt() async {
        let viewModel = viewModel()

        viewModel.onEvent(.systolicChanged("80"))
        viewModel.onEvent(.diastolicChanged("90"))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the rejection") { viewModel.state.error != nil }

        #expect(viewModel.state.error == .systolicNotAboveDiastolic)

        viewModel.onEvent(.systolicChanged("120"))
        #expect(viewModel.state.error == nil)
        navigator.stop()
    }

    /// `BloodPressureEditorViewModelTest.kt:109-136`.
    @Test("editing existing entry preloads fields and keeps timestamp when date unchanged")
    func editingExistingEntryPreloadsFieldsAndKeepsTimestampWhenDateUnchanged() async throws {
        let original = BloodPressureEntry(
            id: "bp-1",
            measuredAt: Self.now,
            timeZone: Self.zone,
            systolic: 130.0,
            diastolic: 85.0,
            pulse: 70.0,
            note: "evening"
        )
        repository.setBloodPressureEntries(original)

        let viewModel = viewModel(entryId: "bp-1")
        await waitUntil("the entry to load") { !viewModel.state.systolicText.isEmpty }

        #expect(viewModel.state.systolicText == "130")
        #expect(viewModel.state.diastolicText == "85")
        #expect(viewModel.state.pulseText == "70")
        #expect(viewModel.state.noteText == "evening")

        viewModel.onEvent(.systolicChanged("125"))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }

        let updated = try #require(repository.currentBloodPressure().first)
        #expect(repository.currentBloodPressure().count == 1)
        #expect(updated.systolic == 125.0)
        #expect(updated.measuredAt == original.measuredAt)
        navigator.stop()
    }

    /// `BloodPressureEditorViewModelTest.kt:138-158`.
    @Test("delete confirms first, then defers the write and closes")
    func deleteConfirmsFirstThenDefersTheWriteAndCloses() async {
        repository.setBloodPressureEntries(BloodPressureEntry(
            id: "bp-1",
            measuredAt: Self.now,
            timeZone: Self.zone,
            systolic: 120.0,
            diastolic: 80.0,
            pulse: nil,
            note: nil
        ))
        let viewModel = viewModel(entryId: "bp-1")
        await waitUntil("the entry to load") { !viewModel.state.systolicText.isEmpty }

        viewModel.onEvent(.deleteClicked)
        #expect(viewModel.state.showDeleteConfirm)
        #expect(navigator.commandLog.isEmpty)
        #expect(!repository.currentBloodPressure().isEmpty)

        viewModel.onEvent(.deleteConfirmed)
        #expect(!viewModel.state.showDeleteConfirm)
        #expect(!repository.currentBloodPressure().isEmpty, "the write waits for the undo window")
        // `BloodPressureEditorViewModel.kt:130` attaches `R.string.vitals_entry_deleted`.
        #expect(deletes.lastRequest?.message == VitalsStrings.entryDeleted)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }
        #expect(!repository.currentBloodPressure().isEmpty, "the write waits for the undo window")

        await deletes.closeUndoWindow()
        await waitUntil("the deferred write") { repository.currentBloodPressure().isEmpty }
        navigator.stop()
    }
}
