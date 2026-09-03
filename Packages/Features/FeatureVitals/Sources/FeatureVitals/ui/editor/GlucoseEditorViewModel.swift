// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/GlucoseEditorViewModel.kt`.
//
// Same shape as `BloodPressureEditorViewModel`, plus the one thing this editor owns: the app-wide
// glucose unit. Two mechanical differences from the Kotlin, both recorded in
// `research-android-vitals.md` §10:
//
//   `preferences.glucoseUnit.first()` → the first element of the `AsyncStream`, taken with a
//   `for await … break`. Swift has no `Flow.first()`, and until it arrives the state carries
//   `GlucoseUnit.mgDl` — the same default Kotlin's initial state does (row 3).
//
//   `viewModelScope.launch { preferences.setGlucoseUnit(newUnit) }` → a plain call. Kotlin needs
//   the coroutine because DataStore's `edit` is `suspend`; `VitalsPreferences.setGlucoseUnit` is
//   synchronous on this side (recorded divergence (b)), so wrapping it in a `Task` would only make
//   the write land after the test's assertion.

import Foundation
import SalusCommon
import SalusModel
import SalusNavigation
import SalusUI

/// Drives the glucose editor (`GlucoseEditorViewModel.kt:25-151`).
@MainActor
@Observable
public final class GlucoseEditorViewModel {
    /// `GlucoseEditorViewModel.kt:35-36`.
    public private(set) var state: GlucoseEditorUiState

    private let entryId: String?
    private let repository: any VitalsRepository
    private let saveGlucoseEntry: SaveGlucoseEntryUseCase
    private let preferences: any VitalsPreferences
    private let clock: any SalusClock
    private let navigator: Navigator
    private let undoableDelete: UndoableDelete

    /// `GlucoseEditorViewModel.kt:38` — kept so a save can tell "the date was not touched" from
    /// "the date was set to the same day", and so the original zone survives an edit.
    private var loadedEntry: GlucoseEntry?

    /// The preference read and, for an existing entry, its load. Boxed so `deinit` can cancel it —
    /// see `CancellationBox`.
    private let loadTask = CancellationBox()

    /// The seven dependencies are the Kotlin constructor (`GlucoseEditorViewModel.kt:26-33`), one
    /// for one — `preferences` is the fourth, exactly where Kotlin puts it.
    public init(
        entryId: String?,
        repository: any VitalsRepository,
        saveGlucoseEntry: SaveGlucoseEntryUseCase,
        preferences: any VitalsPreferences,
        clock: any SalusClock,
        navigator: Navigator,
        undoableDelete: UndoableDelete
    ) {
        self.entryId = entryId
        self.repository = repository
        self.saveGlucoseEntry = saveGlucoseEntry
        self.preferences = preferences
        self.clock = clock
        self.navigator = navigator
        self.undoableDelete = undoableDelete
        state = GlucoseEditorUiState(isNew: entryId == nil)

        // `GlucoseEditorViewModel.kt:40-64` — **one** task, not two: the unit has to be known
        // before the loaded reading can be written into the field, because the field carries the
        // reading *in that unit*.
        loadTask.replace(with: Task { [weak self] in
            guard let self, let unit = await Self.firstUnit(from: preferences) else { return }
            guard let entryId else {
                state.unit = unit
                state.dateEpochDay = clock.todayEpochDay()
                return
            }
            guard let entry = try? await repository.getGlucoseEntry(id: entryId) else { return }
            loadedEntry = entry
            let localDate = entry.measuredAt.wallClock(in: entry.timeZone).date
            state.isNew = false
            state.valueText = Self.formatValue(
                GlucoseConversion.fromMgDl(entry.mgDl, unit: unit),
                unit: unit
            )
            state.unit = unit
            state.measurementContext = entry.measurementContext
            state.noteText = entry.note ?? ""
            state.dateEpochDay = localDate.epochDay
        })
    }

    deinit {
        loadTask.cancel()
    }

    /// `GlucoseEditorViewModel.kt:66-92`.
    public func onEvent(_ event: GlucoseEditorEvent) {
        switch event {
        case let .valueChanged(text):
            state.valueText = text
            state.showInvalidValue = false

        case let .unitSelected(unit):
            switchUnit(to: unit)

        case let .contextSelected(context):
            state.measurementContext = context

        case let .noteChanged(text):
            // `GlucoseEditorViewModel.kt:76-77` — the note leaves the rejection standing.
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

    /// Converts the typed value into the new unit and persists the preference globally
    /// (`GlucoseEditorViewModel.kt:95-108`).
    ///
    /// The write is app-wide on purpose: this segmented control is the *only* place the display
    /// unit is chosen — there is no toggle on the list screen and none in Settings.
    private func switchUnit(to newUnit: GlucoseUnit) {
        guard state.unit != newUnit else { return }

        // `?: current.valueText` — text the parser cannot read is kept verbatim rather than
        // wiped, so a half-typed "5," survives the toggle.
        if let typed = Self.value(of: state.valueText) {
            let mgDl = GlucoseConversion.toMgDl(typed, unit: state.unit)
            state.valueText = Self.formatValue(
                GlucoseConversion.fromMgDl(mgDl, unit: newUnit),
                unit: newUnit
            )
        }
        state.unit = newUnit
        state.showInvalidValue = false
        preferences.setGlucoseUnit(newUnit)
    }

    /// `GlucoseEditorViewModel.kt:110-134`.
    private func save() {
        let current = state
        let value = Self.value(of: current.valueText)
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
                let result = try await saveGlucoseEntry(
                    existingId: entryId,
                    value: value,
                    unit: current.unit,
                    measuredAt: measuredAt,
                    timeZone: clock.timeZone(),
                    measurementContext: current.measurementContext,
                    note: current.noteText
                )
                switch result {
                case .saved:
                    navigator.pop()
                case .invalidValue:
                    state.isSaving = false
                    state.showInvalidValue = true
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

    /// `GlucoseEditorViewModel.kt:136-143`.
    private func delete() {
        guard let entryId else { return }
        state.showDeleteConfirm = false
        // Held for the undo window by an app-scoped controller, so popping this editor does not
        // cancel the deletion (`GlucoseEditorViewModel.kt:139-140`).
        undoableDelete(entryId, message: VitalsStrings.entryDeleted) { [repository] in
            try? await repository.deleteGlucoseEntry(id: entryId)
        }
        navigator.pop()
    }

    /// `preferences.glucoseUnit.first()` (`GlucoseEditorViewModel.kt:42`). nil only when the
    /// stream finishes without ever yielding, which `VitalsPreferencesImpl` does not do.
    private static func firstUnit(from preferences: any VitalsPreferences) async -> GlucoseUnit? {
        for await unit in preferences.glucoseUnit {
            return unit
        }
        return nil
    }

    /// `GlucoseEditorViewModel.kt:99` and `:116` — `replace(',', '.').toDoubleOrNull()`. A Turkish keyboard
    /// produces the comma, and the parser only knows the point.
    private static func value(of text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    /// `GlucoseEditorViewModel.kt:145-150`.
    ///
    /// `Locale.US`, not the device locale — and deliberately so (research §10 row 10): this text is
    /// parsed straight back by `value(of:)`, which only understands the point, so formatting it
    /// with a Turkish decimal comma would make the round trip lossy in exactly the case the toggle
    /// creates. The *list* screen formats the same numbers in the reader's language (the app's
    /// locale, which the shell publishes as `\.locale`); the asymmetry is Android's and is ported
    /// as-is.
    ///
    /// **iOS divergence:** Kotlin's `value.toInt()` saturates at `Int.MAX_VALUE`, Swift's `Int(_:)`
    /// traps, so the whole-number branch is taken only when the value is exactly representable —
    /// a typed 1e20 falls through to `%.1f` instead of crashing. Nothing inside the accepted
    /// 20…600 mg/dL range can tell the two apart.
    private static func formatValue(_ value: Double, unit: GlucoseUnit) -> String {
        switch unit {
        case .mgDl:
            if value.truncatingRemainder(dividingBy: 1.0) == 0, let whole = Int(exactly: value) {
                return String(whole)
            }
            return decimal(value)

        case .mmolL:
            return decimal(value)
        }
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
