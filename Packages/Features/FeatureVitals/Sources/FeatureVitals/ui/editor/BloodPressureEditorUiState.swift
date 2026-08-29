// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/BloodPressureEditorUiState.kt`.

/// Which of the four rejections the last save produced (`BloodPressureEditorUiState.kt:3-8`).
///
/// One optional case rather than `WeightEditorUiState`'s single `showInvalidWeight` flag, because
/// this editor has four fields' worth of rejections and the screen draws exactly one message.
public enum BloodPressureError: Equatable, Sendable {
    case invalidSystolic
    case invalidDiastolic
    case invalidPulse
    case systolicNotAboveDiastolic
}

/// What the blood-pressure editor draws (`BloodPressureEditorUiState.kt:10-20`).
///
/// The date is an `epochDay`, never a `Date`, for the reason `WeightEditorUiState` records: it is a
/// calendar day the user picked, and the instant it becomes is composed once, at save, by
/// `resolveEditorMeasuredAt`.
public struct BloodPressureEditorUiState: Equatable, Sendable {
    public var isNew: Bool
    public var systolicText: String
    public var diastolicText: String
    public var pulseText: String
    public var noteText: String
    public var dateEpochDay: Int?
    public var isSaving: Bool
    public var error: BloodPressureError?
    public var showDeleteConfirm: Bool

    public init(
        isNew: Bool = true,
        systolicText: String = "",
        diastolicText: String = "",
        pulseText: String = "",
        noteText: String = "",
        dateEpochDay: Int? = nil,
        isSaving: Bool = false,
        error: BloodPressureError? = nil,
        showDeleteConfirm: Bool = false
    ) {
        self.isNew = isNew
        self.systolicText = systolicText
        self.diastolicText = diastolicText
        self.pulseText = pulseText
        self.noteText = noteText
        self.dateEpochDay = dateEpochDay
        self.isSaving = isSaving
        self.error = error
        self.showDeleteConfirm = showDeleteConfirm
    }
}

/// Everything the editor can ask the ViewModel to do (`BloodPressureEditorUiState.kt:22-40`).
public enum BloodPressureEditorEvent: Equatable, Sendable {
    case systolicChanged(String)
    case diastolicChanged(String)
    case pulseChanged(String)
    case noteChanged(String)
    case dateSelected(Int)
    case saveClicked
    /// Opens the confirmation; nothing is deleted until it is confirmed
    /// (`BloodPressureEditorUiState.kt:33-34`).
    case deleteClicked
    case deleteDismissed
    case deleteConfirmed
}
