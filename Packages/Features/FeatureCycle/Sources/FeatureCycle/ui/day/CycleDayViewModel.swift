// Ported 1:1 from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/
// ui/day/CycleDayViewModel.kt`.
//
// `MutableStateFlow` + `update { it.copy(…) }` becomes an `@Observable` `state` mutated in place,
// and `viewModelScope.launch` becomes `Task { }` inside a `@MainActor` type — the spellings
// `CycleViewModel` and `MedicationEditorViewModel` settled, member for member.
//
// `repository.observeSymptoms().first()` (`CycleDayViewModel.kt:30`) is a `for try await … break`.
// It reads as one value but it is deliberately a *collection*: the real repository seeds the
// starter catalog on first collection (`CycleRepository.kt:21-22`), so subscribing is what makes a
// fresh install have symptoms to show. `first(where: { _ in true })` would do the same thing and
// say less about why.
//
// Two arms have no Kotlin twin, and both are the iOS protocol's `throws`:
//   - the load. `CycleRepository` is `async throws` here (a database read can fail, and the mapper
//     can reject an unreadable `flow` or `mood`), so a failure leaves `isLoading` true and the
//     screen spinning. That is this port's house pattern and Android's own behaviour — Kotlin's
//     `stateIn` initial value is the loading state and a cancelled flow never replaces it
//     (`CycleViewModel.swift`'s `start` records the same ruling).
//   - the save. A throw skips `navigator.pop()`, exactly as a failing `suspend` call ends the
//     coroutine Kotlin launched before it reaches its own `pop()`. The screen stays open with what
//     the user typed still in it, which is the only outcome that does not lose the entry.
//
// `isSaving` is never set back to false, on either platform: the only way out of the save is the
// pop, so a screen that is on its way out never re-enables its button.

import Foundation
import Observation
import SalusCommon
import SalusModel
import SalusNavigation

/// Drives one day's log — symptoms, flow, mood and note (`CycleDayViewModel.kt:16-95`).
@MainActor
@Observable
public final class CycleDayViewModel {
    /// `CycleDayViewModel.kt:25-26` — what the screen draws.
    public private(set) var state: CycleDayUiState

    /// `CycleDayViewModel.kt:23` — the day being logged, derived once from the key's epoch day.
    private let date: LocalDate
    private let saveCycleDay: SaveCycleDayUseCase
    private let navigator: Navigator

    /// The catalog read. Boxed so `deinit` can cancel it — see `CancellationBox`.
    private let loadTask = CancellationBox()

    /// The write. Boxed for the same reason, and separately: a save started just before the screen
    /// goes away must be cancellable without touching the load.
    private let saveTask = CancellationBox()

    /// Four parameters, which are the four Koin resolves for
    /// `viewModel { CycleDayViewModel(...) }` (`CycleModule.kt:49-56`); `epochDay` is the one it
    /// takes from `parametersOf`.
    public init(
        epochDay: Int,
        repository: any CycleRepository,
        saveCycleDay: SaveCycleDayUseCase,
        navigator: Navigator
    ) {
        date = LocalDate(epochDay: epochDay)
        self.saveCycleDay = saveCycleDay
        self.navigator = navigator
        state = CycleDayUiState(epochDay: epochDay)

        // `CycleDayViewModel.kt:28-50`.
        let date = date
        loadTask.replace(with: Task { [weak self, repository] in
            guard let loaded = try? await Self.load(from: repository, on: date) else { return }
            self?.apply(catalog: loaded.catalog, existing: loaded.existing)
        })
    }

    deinit {
        loadTask.cancel()
        saveTask.cancel()
    }

    /// `CycleDayViewModel.kt:30-31` — the catalog's first emission (which is what seeds it), then
    /// whatever this day already holds.
    ///
    /// `static` so the load captures nothing but its two arguments — the ViewModel itself is
    /// touched again only in ``apply(catalog:existing:)``. Both `await`s suspend onto the
    /// repository's own executor, so being main-actor-isolated costs nothing here.
    private static func load(
        from repository: any CycleRepository,
        on date: LocalDate
    ) async throws -> (catalog: [Symptom], existing: CycleDayLog?) {
        var catalog: [Symptom] = []
        for try await symptoms in repository.observeSymptoms() {
            catalog = symptoms
            break
        }
        return try await (catalog, repository.getDayLog(on: date))
    }

    /// `CycleDayViewModel.kt:32-48`.
    private func apply(catalog: [Symptom], existing: CycleDayLog?) {
        state.isLoading = false
        state.symptoms = catalog.map { symptom in
            CycleSymptomUi(
                id: symptom.id,
                nameKey: symptom.nameKey,
                isSelected: existing?.symptomIds.contains(symptom.id) == true
            )
        }
        state.flow = existing?.flow
        state.mood = existing?.mood
        state.noteText = existing?.note ?? ""
    }

    /// `CycleDayViewModel.kt:52-80`.
    public func onEvent(_ event: CycleDayEvent) {
        switch event {
        case let .symptomToggled(id):
            guard let index = state.symptoms.firstIndex(where: { $0.id == id }) else { return }
            state.symptoms[index].isSelected.toggle()

        // `CycleDayViewModel.kt:68-70` and `:72-74` — the same value again clears the choice, so a
        // flow or a mood tapped by mistake has a way back without a "none" chip.
        case let .flowSelected(level):
            state.flow = state.flow == level ? nil : level

        case let .moodSelected(mood):
            state.mood = state.mood == mood ? nil : mood

        case let .noteChanged(text):
            state.noteText = text

        case .saveClicked:
            save()
        }
    }

    /// `CycleDayViewModel.kt:82-95`.
    ///
    /// The values are read here rather than inside the task, exactly where Kotlin reads them
    /// (`CycleDayViewModel.kt:83`): what is saved is what the screen showed when the button was
    /// pressed.
    private func save() {
        let current = state
        let selectedIds = Set(current.symptoms.filter(\.isSelected).map(\.id))
        saveTask.replace(with: Task { [weak self, saveCycleDay, date] in
            self?.state.isSaving = true
            let saved = try? await saveCycleDay(
                date: date,
                flow: current.flow,
                mood: current.mood,
                // The use case trims and drops an all-whitespace note
                // (`SaveCycleDayUseCase.kt:32`), so the raw field text is what goes in.
                note: current.noteText,
                symptomIds: selectedIds
            )
            // A throw skips the pop; see the file header. A ViewModel that went away during the
            // write skips it too — `viewModelScope` is cancelled by `onCleared()` before Kotlin
            // reaches its own `pop()`, and popping a stack this screen already left would take a
            // second screen with it.
            guard let self, saved != nil else { return }
            navigator.pop()
        })
    }
}
