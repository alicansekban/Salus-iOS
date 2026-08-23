// Ported 1:1 from `feature/vitals/src/test/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/WeightEditorViewModelTest.kt` — the four cases, in the Kotlin order, with the Kotlin
// inputs and expectations.
//
// `advanceUntilIdle()` becomes `waitUntil`: the ViewModel's work is on the main actor's cooperative
// queue rather than on a virtual scheduler, and no test here waits on wall-clock time.

import Foundation
import SalusCommon
import SalusNavigation
import SalusTesting
import Testing

@testable import FeatureVitals

@Suite("WeightEditorViewModel")
@MainActor
struct WeightEditorViewModelTests {
    /// `WeightEditorViewModelTest.kt:32-34`.
    private static let now = Date(timeIntervalSince1970: 1_755_000_000)
    private static let zone = FixedSalusClock.defaultZone

    private let clock = FixedSalusClock(
        now: WeightEditorViewModelTests.now,
        timeZone: WeightEditorViewModelTests.zone
    )
    private let repository = FakeVitalsRepository()
    private let navigator = FakeNavigator()
    private let deletes = TestDeletes()

    /// `WeightEditorViewModelTest.kt:39-47`.
    private func viewModel(entryId: String? = nil) -> WeightEditorViewModel {
        WeightEditorViewModel(
            entryId: entryId,
            repository: repository,
            saveWeightEntry: SaveWeightEntryUseCase(
                repository: repository,
                idGenerator: FixedIdGenerator(id: "new-id")
            ),
            clock: clock,
            navigator: navigator.navigator,
            undoableDelete: deletes.undoableDelete
        )
    }

    /// `WeightEditorViewModelTest.kt:49-59`.
    @Test("saving a valid value stores entry and closes")
    func savingAValidValueStoresEntryAndCloses() async throws {
        let viewModel = viewModel()

        viewModel.onEvent(.valueChanged("82,5"))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }

        let saved = try #require(repository.current().first)
        #expect(repository.current().count == 1)
        #expect(saved.kilograms == 82.5)
        #expect(saved.id == "new-id")
        navigator.stop()
    }

    /// `WeightEditorViewModelTest.kt:61-71`.
    @Test("invalid value shows error and saves nothing")
    func invalidValueShowsErrorAndSavesNothing() async {
        let viewModel = viewModel()

        viewModel.onEvent(.valueChanged("5"))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the rejection") { viewModel.state.showInvalidWeight }

        #expect(repository.current().isEmpty)
        #expect(navigator.commandLog.isEmpty)
        navigator.stop()
    }

    /// `WeightEditorViewModelTest.kt:73-98`.
    @Test("editing existing entry preloads fields and keeps timestamp when date unchanged")
    func editingExistingEntryPreloadsFieldsAndKeepsTimestampWhenDateUnchanged() async throws {
        let original = WeightEntry(
            id: "e1",
            measuredAt: Self.now,
            timeZone: Self.zone,
            kilograms: 78.0,
            note: "morning"
        )
        repository.setEntries(original)

        let viewModel = viewModel(entryId: "e1")
        await waitUntil("the entry to load") { !viewModel.state.valueText.isEmpty }

        #expect(viewModel.state.valueText == "78")
        #expect(viewModel.state.noteText == "morning")

        viewModel.onEvent(.valueChanged("79"))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }

        let updated = try #require(repository.current().first)
        #expect(repository.current().count == 1)
        #expect(updated.kilograms == 79.0)
        #expect(updated.measuredAt == original.measuredAt)
        navigator.stop()
    }

    /// `WeightEditorViewModelTest.kt:100-120`.
    @Test("delete confirms first, then defers the write and closes")
    func deleteConfirmsFirstThenDefersTheWriteAndCloses() async {
        repository.setEntries(WeightEntry(
            id: "e1",
            measuredAt: Self.now,
            timeZone: Self.zone,
            kilograms: 78.0,
            note: nil
        ))
        let viewModel = viewModel(entryId: "e1")
        await waitUntil("the entry to load") { !viewModel.state.valueText.isEmpty }

        viewModel.onEvent(.deleteClicked)
        #expect(viewModel.state.showDeleteConfirm)
        #expect(navigator.commandLog.isEmpty)
        #expect(!repository.current().isEmpty)

        viewModel.onEvent(.deleteConfirmed)
        #expect(!viewModel.state.showDeleteConfirm)
        #expect(!repository.current().isEmpty, "the write waits for the undo window")
        // `WeightEditorViewModel.kt:109` attaches `R.string.vitals_entry_deleted`.
        #expect(deletes.lastRequest?.message == VitalsStrings.entryDeleted)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }
        #expect(!repository.current().isEmpty, "the write waits for the undo window")

        await deletes.closeUndoWindow()
        await waitUntil("the deferred write") { repository.current().isEmpty }
        navigator.stop()
    }
}
