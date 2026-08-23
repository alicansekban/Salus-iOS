// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/WeightEditorViewModel.kt`.
//
// `MutableStateFlow` + `update { it.copy(…) }` becomes an `@Observable` `state` mutated in place:
// a `struct` assignment is the `copy`, and SwiftUI observes the property the way Compose collects
// the flow. `viewModelScope.launch` becomes `Task { }` inside a `@MainActor` type, which inherits
// the actor and dies with the ViewModel.

import Foundation
import SalusCommon
import SalusNavigation
import SalusUI

/// Drives the weight editor (`WeightEditorViewModel.kt:21-119`).
@MainActor
@Observable
public final class WeightEditorViewModel {
    /// `WeightEditorViewModel.kt:30-31`.
    public private(set) var state: WeightEditorUiState

    private let entryId: String?
    private let repository: any VitalsRepository
    private let saveWeightEntry: SaveWeightEntryUseCase
    private let clock: any SalusClock
    private let navigator: Navigator
    private let undoableDelete: UndoableDelete

    /// `WeightEditorViewModel.kt:33` — kept so a save can tell "the date was not touched" from
    /// "the date was set to the same day", and so the original zone survives an edit.
    private var loadedEntry: WeightEntry?

    /// The existing entry's load. Boxed so `deinit` can cancel it — see `CancellationBox`.
    private let loadTask = CancellationBox()

    public init(
        entryId: String?,
        repository: any VitalsRepository,
        saveWeightEntry: SaveWeightEntryUseCase,
        clock: any SalusClock,
        navigator: Navigator,
        undoableDelete: UndoableDelete
    ) {
        self.entryId = entryId
        self.repository = repository
        self.saveWeightEntry = saveWeightEntry
        self.clock = clock
        self.navigator = navigator
        self.undoableDelete = undoableDelete
        state = WeightEditorUiState(isNew: entryId == nil)

        // `WeightEditorViewModel.kt:35-54`.
        guard let entryId else {
            state.dateEpochDay = clock.todayEpochDay()
            return
        }
        loadTask.replace(with: Task { [weak self] in
            guard
                let self,
                let entry = try? await repository.getWeightEntry(id: entryId)
            else {
                return
            }
            loadedEntry = entry
            let localDate = entry.measuredAt.wallClock(in: entry.timeZone).date
            state.isNew = false
            state.valueText = Self.formatValue(entry.kilograms)
            state.noteText = entry.note ?? ""
            state.dateEpochDay = localDate.epochDay
        })
    }

    deinit {
        loadTask.cancel()
    }

    /// `WeightEditorViewModel.kt:56-77`.
    public func onEvent(_ event: WeightEditorEvent) {
        switch event {
        case let .valueChanged(text):
            state.valueText = text
            state.showInvalidWeight = false

        case let .noteChanged(text):
            state.noteText = text

        case let .dateSelected(epochDay):
            state.dateEpochDay = epochDay

        case .saveClicked:
            save()

        case .deleteClicked:
            state.showDeleteConfirm = true

        case .deleteDismissed:
            state.showDeleteConfirm = false

        case .deleteConfirmed:
            delete()
        }
    }

    /// `WeightEditorViewModel.kt:79-102`.
    private func save() {
        let current = state
        // `valueText.replace(',', '.').toDoubleOrNull()` — a Turkish keyboard produces the comma,
        // and the parser only knows the point.
        let kilograms = Double(current.valueText.replacingOccurrences(of: ",", with: "."))
        Task { [weak self] in
            guard let self else { return }
            state.isSaving = true
            let measuredAt = resolveEditorMeasuredAt(
                clock: clock,
                selectedEpochDay: current.dateEpochDay,
                existingMeasuredAt: loadedEntry?.measuredAt,
                existingTimeZone: loadedEntry?.timeZone
            )
            do {
                let result = try await saveWeightEntry(
                    existingId: entryId,
                    kilograms: kilograms,
                    measuredAt: measuredAt,
                    timeZone: clock.timeZone(),
                    note: current.noteText
                )
                switch result {
                case .saved:
                    navigator.pop()
                case .invalidWeight:
                    state.isSaving = false
                    state.showInvalidWeight = true
                }
            } catch {
                // No Kotlin twin: `saveWeightEntry` is a `suspend fun` whose failure propagates
                // into `viewModelScope`, and the iOS repository declares `throws` so a write
                // failure can reach the collector rather than ending quietly
                // (`VitalsRepository.swift:9-13`). The editor stays open with its text intact and
                // the button re-enabled, which is the only thing the user can act on.
                state.isSaving = false
            }
        }
    }

    /// `WeightEditorViewModel.kt:104-111`.
    private func delete() {
        guard let entryId else { return }
        state.showDeleteConfirm = false
        // Held for the undo window by an app-scoped controller, so popping this editor does not
        // cancel the deletion (`WeightEditorViewModel.kt:107-108`).
        undoableDelete(entryId, message: VitalsStrings.entryDeleted) { [repository] in
            try? await repository.deleteWeightEntry(id: entryId)
        }
        navigator.pop()
    }

    /// `WeightEditorViewModel.kt:113-118`.
    ///
    /// `Locale.US` is the point-decimal locale, not the user's: this fills a text field the parser
    /// above reads back, so a Turkish comma here would round-trip into a rejected value.
    private static func formatValue(_ kilograms: Double) -> String {
        if kilograms.truncatingRemainder(dividingBy: 1.0) == 0.0 {
            return String(Int(kilograms))
        }
        return String(format: "%.1f", locale: Locale(identifier: "en_US"), kilograms)
    }
}
