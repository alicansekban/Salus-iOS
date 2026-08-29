// Ported 1:1 from `feature/vitals/src/test/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/GlucoseEditorViewModelTest.kt` — the six cases, in the Kotlin order, with the Kotlin
// inputs and expectations.
//
// `advanceUntilIdle()` becomes `waitUntil`, for the reason `WeightEditorViewModelTests` records:
// the ViewModel's work is on the main actor's cooperative queue rather than on a virtual
// scheduler, and no test here waits on wall-clock time. The one extra wait this file needs over
// its BP twin is the init's read of `preferences.glucoseUnit`, which is asynchronous on both
// platforms — `dateEpochDay` (new entry) and `valueText` (existing entry) are what it lands.

import Foundation
import SalusCommon
import SalusModel
import SalusNavigation
import SalusTesting
import Testing

@testable import FeatureVitals

@Suite("GlucoseEditorViewModel")
@MainActor
struct GlucoseEditorViewModelTests {
    /// `GlucoseEditorViewModelTest.kt:36-38`.
    private static let now = Date(timeIntervalSince1970: 1_755_000_000)
    private static let zone = FixedSalusClock.defaultZone

    private let clock = FixedSalusClock(
        now: GlucoseEditorViewModelTests.now,
        timeZone: GlucoseEditorViewModelTests.zone
    )
    private let repository = FakeVitalsRepository()
    private let navigator = FakeNavigator()
    private let preferences = FakeVitalsPreferences()
    private let deletes = TestDeletes()

    /// `GlucoseEditorViewModelTest.kt:44-53`.
    private func viewModel(entryId: String? = nil) -> GlucoseEditorViewModel {
        GlucoseEditorViewModel(
            entryId: entryId,
            repository: repository,
            saveGlucoseEntry: SaveGlucoseEntryUseCase(
                repository: repository,
                idGenerator: FixedIdGenerator(id: "new-id")
            ),
            preferences: preferences,
            clock: clock,
            navigator: navigator.navigator,
            undoableDelete: deletes.undoableDelete
        )
    }

    /// `GlucoseEditorViewModelTest.kt:55-70`.
    @Test("saving a valid mg dL value stores entry with context and closes")
    func savingAValidMgDLValueStoresEntryWithContextAndCloses() async throws {
        let viewModel = viewModel()
        await waitUntil("the preferred unit to arrive") { viewModel.state.dateEpochDay != nil }

        viewModel.onEvent(.valueChanged("110"))
        viewModel.onEvent(.contextSelected(.fasting))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }

        let saved = try #require(repository.currentGlucose().first)
        #expect(repository.currentGlucose().count == 1)
        #expect(saved.id == "new-id")
        #expect(saved.mgDl == 110.0)
        #expect(saved.measurementContext == .fasting)
        navigator.stop()
    }

    /// `GlucoseEditorViewModelTest.kt:72-85`.
    @Test("unit toggle converts the typed value and persists the preference")
    func unitToggleConvertsTheTypedValueAndPersistsThePreference() async {
        let viewModel = viewModel()
        await waitUntil("the preferred unit to arrive") { viewModel.state.dateEpochDay != nil }
        #expect(viewModel.state.unit == .mgDl)

        viewModel.onEvent(.valueChanged("108"))
        viewModel.onEvent(.unitSelected(.mmolL))

        #expect(viewModel.state.unit == .mmolL)
        #expect(viewModel.state.valueText == "6.0") // 108 / 18.0182 = 5.99...
        #expect(preferences.currentUnit() == .mmolL)
        navigator.stop()
    }

    /// `GlucoseEditorViewModelTest.kt:87-103`.
    @Test("value typed in mmol L is stored canonically in mg dL")
    func valueTypedInMmolLIsStoredCanonicallyInMgDL() async throws {
        let viewModel = viewModel()
        await waitUntil("the preferred unit to arrive") { viewModel.state.dateEpochDay != nil }

        viewModel.onEvent(.unitSelected(.mmolL))
        viewModel.onEvent(.valueChanged("5,5"))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }

        let saved = try #require(repository.currentGlucose().first)
        #expect(repository.currentGlucose().count == 1)
        #expect(abs(saved.mgDl - 5.5 * GlucoseConversion.mgDlPerMmolL) < 1e-9)
        navigator.stop()
    }

    /// `GlucoseEditorViewModelTest.kt:105-117`.
    @Test("invalid value shows error and saves nothing")
    func invalidValueShowsErrorAndSavesNothing() async {
        let viewModel = viewModel()
        await waitUntil("the preferred unit to arrive") { viewModel.state.dateEpochDay != nil }

        viewModel.onEvent(.valueChanged("5"))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the rejection") { viewModel.state.showInvalidValue }

        #expect(viewModel.state.showInvalidValue)
        #expect(repository.currentGlucose().isEmpty)
        #expect(navigator.commandLog.isEmpty)
        navigator.stop()
    }

    /// `GlucoseEditorViewModelTest.kt:119-146`.
    @Test("editing existing entry preloads fields in the preferred unit and keeps timestamp")
    func editingExistingEntryPreloadsFieldsInThePreferredUnitAndKeepsTimestamp() async throws {
        preferences.setGlucoseUnit(.mmolL)
        let original = GlucoseEntry(
            id: "g-1",
            measuredAt: Self.now,
            timeZone: Self.zone,
            mgDl: 108.0,
            measurementContext: .postMeal,
            note: "lunch"
        )
        repository.setGlucoseEntries(original)

        let viewModel = viewModel(entryId: "g-1")
        await waitUntil("the entry to load") { !viewModel.state.valueText.isEmpty }

        #expect(viewModel.state.unit == .mmolL)
        #expect(viewModel.state.valueText == "6.0")
        #expect(viewModel.state.measurementContext == .postMeal)
        #expect(viewModel.state.noteText == "lunch")

        viewModel.onEvent(.saveClicked)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }

        let updated = try #require(repository.currentGlucose().first)
        #expect(repository.currentGlucose().count == 1)
        #expect(updated.measuredAt == original.measuredAt)
        #expect(updated.measurementContext == .postMeal)
        navigator.stop()
    }

    /// `GlucoseEditorViewModelTest.kt:148-169`.
    @Test("delete confirms first, then defers the write and closes")
    func deleteConfirmsFirstThenDefersTheWriteAndCloses() async {
        repository.setGlucoseEntries(GlucoseEntry(
            id: "g-1",
            measuredAt: Self.now,
            timeZone: Self.zone,
            mgDl: 108.0,
            measurementContext: nil,
            note: nil
        ))
        let viewModel = viewModel(entryId: "g-1")
        await waitUntil("the entry to load") { !viewModel.state.valueText.isEmpty }

        viewModel.onEvent(.deleteClicked)
        #expect(viewModel.state.showDeleteConfirm)
        #expect(navigator.commandLog.isEmpty)
        #expect(!repository.currentGlucose().isEmpty)

        viewModel.onEvent(.deleteConfirmed)
        #expect(!viewModel.state.showDeleteConfirm)
        #expect(!repository.currentGlucose().isEmpty, "the write waits for the undo window")
        // `GlucoseEditorViewModel.kt:131` attaches `R.string.vitals_entry_deleted`.
        #expect(deletes.lastRequest?.message == VitalsStrings.entryDeleted)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }
        #expect(!repository.currentGlucose().isEmpty, "the write waits for the undo window")

        await deletes.closeUndoWindow()
        await waitUntil("the deferred write") { repository.currentGlucose().isEmpty }
        navigator.stop()
    }
}
