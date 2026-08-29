// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/GlucoseEditorUiState.kt`.

import SalusModel

/// What the glucose editor draws (`GlucoseEditorUiState.kt:6-16`).
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
        self.unit = unit
        self.measurementContext = measurementContext
        self.noteText = noteText
        self.dateEpochDay = dateEpochDay
        self.isSaving = isSaving
        self.showInvalidValue = showInvalidValue
        self.showDeleteConfirm = showDeleteConfirm
    }
}

/// Everything the editor can ask the ViewModel to do (`GlucoseEditorUiState.kt:18-36`).
public enum GlucoseEditorEvent: Equatable, Sendable {
    case valueChanged(String)
    case unitSelected(GlucoseUnit)
    /// nil deselects — tapping the selected chip clears the context (`GlucoseEditorScreen.kt:130`).
    case contextSelected(MeasurementContext?)
    case noteChanged(String)
    case dateSelected(Int)
    case saveClicked
    /// Opens the confirmation; nothing is deleted until it is confirmed
    /// (`GlucoseEditorUiState.kt:29-30`).
    case deleteClicked
    case deleteDismissed
    case deleteConfirmed
}
