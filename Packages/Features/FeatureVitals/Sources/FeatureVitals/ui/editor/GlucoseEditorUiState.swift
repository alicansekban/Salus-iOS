// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/GlucoseEditorUiState.kt`.

import Foundation
import SalusModel

/// What the glucose editor draws (`GlucoseEditorUiState.kt:6-30`).
///
/// `valueText` is the reading the user entered, and only that: a new reading starts blank, with
/// ``suggestedValue`` shown as a dimmed suggestion in the stepper. Typing a value or nudging the
/// suggestion fills it in, which is what ``hasValue`` — and therefore Save — waits for.
/// ``suggestedValue`` is expressed in ``unit``, like `valueText`: switching the unit while the
/// field is still showing a suggestion converts the suggestion instead of the value, because there
/// is no value to convert yet (`GlucoseEditorUiState.kt:6-14`).
///
/// `showInvalidValue` is a `Bool`, not a `BloodPressureError`-shaped enum, because this editor has
/// exactly one rejection: the use case answers `invalidValue` for a missing value and for one
/// outside 20…600 mg/dL alike. The two shapes stay apart on purpose.
///
/// `unit` is what the *field* is typed in, never what gets stored — storage is always mg/dL. It is
/// seeded from the app-wide preference and writing it back is `switchUnit`'s job.
public struct GlucoseEditorUiState: Equatable, Sendable {
    public var isNew: Bool
    public var valueText: String
    public var suggestedValue: Double
    public var unit: GlucoseUnit
    public var measurementContext: MeasurementContext?
    public var noteText: String
    public var dateEpochDay: Int?
    public var isSaving: Bool
    public var showInvalidValue: Bool
    public var showDeleteConfirm: Bool

    public init(
        isNew: Bool = true,
        valueText: String = "",
        suggestedValue: Double = GlucoseEditorUiState.defaultSuggestedMgDl,
        unit: GlucoseUnit = .mgDl,
        measurementContext: MeasurementContext? = nil,
        noteText: String = "",
        dateEpochDay: Int? = nil,
        isSaving: Bool = false,
        showInvalidValue: Bool = false,
        showDeleteConfirm: Bool = false
    ) {
        self.isNew = isNew
        self.valueText = valueText
        self.suggestedValue = suggestedValue
        self.unit = unit
        self.measurementContext = measurementContext
        self.noteText = noteText
        self.dateEpochDay = dateEpochDay
        self.isSaving = isSaving
        self.showInvalidValue = showInvalidValue
        self.showDeleteConfirm = showDeleteConfirm
    }

    /// `GlucoseEditorUiState.kt:27`.
    public var hasValue: Bool { !valueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// `GlucoseEditorUiState.kt:29`.
    public var saveEnabled: Bool { !isSaving && hasValue }

    /// Where a new reading starts before anything is entered, in the canonical unit — a
    /// suggestion, never a value. Every display unit derives from this one, so the suggestion
    /// survives a unit round trip unchanged (`GlucoseEditorUiState.kt:32-37`).
    public static let defaultSuggestedMgDl = 100.0
}

/// Everything the editor can ask the ViewModel to do (`GlucoseEditorUiState.kt:39-58`).
public enum GlucoseEditorEvent: Equatable, Sendable {
    case valueChanged(String)
    case unitSelected(GlucoseUnit)
    /// nil deselects — tapping the selected chip clears the context (`GlucoseEditorScreen.kt:130`).
    case contextSelected(MeasurementContext?)
    case noteChanged(String)
    case dateSelected(Int)
    case saveClicked
    /// Opens the confirmation; nothing is deleted until it is confirmed
    /// (`GlucoseEditorUiState.kt:52-53`).
    case deleteClicked
    case deleteDismissed
    case deleteConfirmed
}
