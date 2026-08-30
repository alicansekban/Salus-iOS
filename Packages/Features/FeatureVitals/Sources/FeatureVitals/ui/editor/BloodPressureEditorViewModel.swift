// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/BloodPressureEditorViewModel.kt`.
//
// Same shape as `WeightEditorViewModel`, and for the same reasons: `MutableStateFlow` +
// `update { it.copy(…) }` becomes an `@Observable` `state` mutated in place, and
// `viewModelScope.launch` becomes a `Task { }` inside a `@MainActor` type.

import Foundation
import SalusCommon
import SalusModel
import SalusNavigation
import SalusUI

/// Drives the blood-pressure editor (`BloodPressureEditorViewModel.kt:21-138`).
@MainActor
@Observable
public final class BloodPressureEditorViewModel {
    /// `BloodPressureEditorViewModel.kt:30-31`.
    public private(set) var state: BloodPressureEditorUiState

    private let entryId: String?
    private let repository: any VitalsRepository
    private let saveBloodPressureEntry: SaveBloodPressureEntryUseCase
    private let clock: any SalusClock
    private let navigator: Navigator
    private let undoableDelete: UndoableDelete

    /// `BloodPressureEditorViewModel.kt:33` — kept so a save can tell "the date was not touched"
    /// from "the date was set to the same day", and so the original zone survives an edit.
    private var loadedEntry: BloodPressureEntry?

    /// The existing entry's load. Boxed so `deinit` can cancel it — see `CancellationBox`.
    private let loadTask = CancellationBox()

    public init(
        entryId: String?,
        repository: any VitalsRepository,
        saveBloodPressureEntry: SaveBloodPressureEntryUseCase,
        clock: any SalusClock,
        navigator: Navigator,
        undoableDelete: UndoableDelete
    ) {
        self.entryId = entryId
        self.repository = repository
        self.saveBloodPressureEntry = saveBloodPressureEntry
        self.clock = clock
        self.navigator = navigator
        self.undoableDelete = undoableDelete
        state = BloodPressureEditorUiState(isNew: entryId == nil)

        // `BloodPressureEditorViewModel.kt:35-56`.
        guard let entryId else {
            state.dateEpochDay = clock.todayEpochDay()
            return
        }
        loadTask.replace(with: Task { [weak self] in
            guard
                let self,
                let entry = try? await repository.getBloodPressureEntry(id: entryId)
            else {
                return
            }
            loadedEntry = entry
            let localDate = entry.measuredAt.wallClock(in: entry.timeZone).date
            state.isNew = false
            state.systolicText = Self.formatValue(entry.systolic)
            state.diastolicText = Self.formatValue(entry.diastolic)
            state.pulseText = entry.pulse.map(Self.formatValue) ?? ""
            state.noteText = entry.note ?? ""
            state.dateEpochDay = localDate.epochDay
        })
    }

    deinit {
        loadTask.cancel()
    }

    /// `BloodPressureEditorViewModel.kt:58-85`.
    public func onEvent(_ event: BloodPressureEditorEvent) {
        switch event {
        case let .systolicChanged(text):
            state.systolicText = text
            state.error = nil

        case let .diastolicChanged(text):
            state.diastolicText = text
            state.error = nil

        case let .pulseChanged(text):
            state.pulseText = text
            state.error = nil

        case let .noteChanged(text):
            // `BloodPressureEditorViewModel.kt:69-70` — the note leaves the error standing.
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

    /// `BloodPressureEditorViewModel.kt:87-122`.
    private func save() {
        let current = state
        let systolic = Self.value(of: current.systolicText)
        let diastolic = Self.value(of: current.diastolicText)
        // `pulseText.takeIf { it.isNotBlank() }?.toValueOrNull()` — a cuff that does not measure a
        // pulse is a normal cuff, so an empty field is nil rather than a rejected value.
        let pulse = current.pulseText.trimmingCharacters(in: .whitespaces).isEmpty
            ? nil
            : Self.value(of: current.pulseText)
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
                let result = try await saveBloodPressureEntry(
                    existingId: entryId,
                    systolic: systolic,
                    diastolic: diastolic,
                    pulse: pulse,
                    measuredAt: measuredAt,
                    timeZone: clock.timeZone(),
                    note: current.noteText
                )
                switch result {
                case .saved:
                    navigator.pop()
                case .invalidSystolic:
                    showError(.invalidSystolic)
                case .invalidDiastolic:
                    showError(.invalidDiastolic)
                case .invalidPulse:
                    showError(.invalidPulse)
                case .systolicNotAboveDiastolic:
                    showError(.systolicNotAboveDiastolic)
                }
            } catch {
                // No Kotlin twin, for the reason `WeightEditorViewModel.save()` records: the iOS
                // repository declares `throws`, so a write failure can reach here where Kotlin's
                // propagates into `viewModelScope`. The editor stays open with its text intact and
                // the button re-enabled, which is the only thing the user can act on.
                state.isSaving = false
            }
        }
    }

    /// `BloodPressureEditorViewModel.kt:124-126`.
    private func showError(_ error: BloodPressureError) {
        state.isSaving = false
        state.error = error
    }

    /// `BloodPressureEditorViewModel.kt:128-135`.
    private func delete() {
        guard let entryId else { return }
        state.showDeleteConfirm = false
        // Held for the undo window by an app-scoped controller, so popping this editor does not
        // cancel the deletion (`BloodPressureEditorViewModel.kt:131-132`).
        undoableDelete(entryId, message: VitalsStrings.entryDeleted) { [repository] in
            try? await repository.deleteBloodPressureEntry(id: entryId)
        }
        navigator.pop()
    }

    /// `BloodPressureEditorViewModel.kt:137` — `replace(',', '.').toDoubleOrNull()`. A Turkish
    /// keyboard produces the comma, and the parser only knows the point.
    private static func value(of text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    /// `BloodPressureEditorViewModel.kt:46-48` — `roundToInt().toString()`. The three readings are
    /// stored as `Double` because they share one `REAL` column set with weight and glucose, but a
    /// cuff reports whole numbers and that is what the field shows.
    private static func formatValue(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}
