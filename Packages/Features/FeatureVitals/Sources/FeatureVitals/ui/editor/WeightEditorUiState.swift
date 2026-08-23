// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/WeightEditorUiState.kt`.

/// What the weight editor draws (`WeightEditorUiState.kt:3-11`).
///
/// The date is an `epochDay`, never a `Date`: it is a calendar day the user picked, and the instant
/// it becomes is composed once, at save, by `resolveEditorMeasuredAt` (`CLAUDE.md`, the `LocalDate`
/// rule).
public struct WeightEditorUiState: Equatable, Sendable {
    public var isNew: Bool
    public var valueText: String
    public var noteText: String
    public var dateEpochDay: Int?
    public var isSaving: Bool
    public var showInvalidWeight: Bool
    public var showDeleteConfirm: Bool

    public init(
        isNew: Bool = true,
        valueText: String = "",
        noteText: String = "",
        dateEpochDay: Int? = nil,
        isSaving: Bool = false,
        showInvalidWeight: Bool = false,
        showDeleteConfirm: Bool = false
    ) {
        self.isNew = isNew
        self.valueText = valueText
        self.noteText = noteText
        self.dateEpochDay = dateEpochDay
        self.isSaving = isSaving
        self.showInvalidWeight = showInvalidWeight
        self.showDeleteConfirm = showDeleteConfirm
    }
}

/// Everything the editor can ask the ViewModel to do (`WeightEditorUiState.kt:13-28`).
public enum WeightEditorEvent: Equatable, Sendable {
    case valueChanged(String)
    case noteChanged(String)
    case dateSelected(Int)
    case saveClicked
    /// Opens the confirmation; nothing is deleted until it is confirmed
    /// (`WeightEditorUiState.kt:22-23`).
    case deleteClicked
    case deleteDismissed
    case deleteConfirmed
}
