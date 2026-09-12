// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/BloodPressureEditorUiState.kt`.

import Foundation

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

/// What the blood-pressure editor draws (`BloodPressureEditorUiState.kt:10-36`).
///
/// The three texts hold what the user entered, and only that: a new reading starts blank, with
/// `suggested…` shown as a dimmed suggestion in each stepper. Typing a value or nudging a
/// suggestion fills the text in. A reading is a pair, so Save waits for both ``hasSystolic`` and
/// ``hasDiastolic``; the pulse stays optional and may be left as its suggestion. An edit starts
/// with the stored values, so they are values from the first frame
/// (`BloodPressureEditorUiState.kt:10-16`).
///
/// The date is an `epochDay`, never a `Date`, for the reason `WeightEditorUiState` records: it is a
/// calendar day the user picked, and the instant it becomes is composed once, at save, by
/// `resolveEditorMeasuredAt`.
public struct BloodPressureEditorUiState: Equatable, Sendable {
    public var isNew: Bool
    public var systolicText: String
    public var diastolicText: String
    public var pulseText: String
    public var suggestedSystolic: Double
    public var suggestedDiastolic: Double
    public var suggestedPulse: Double
    public var noteText: String
    public var dateEpochDay: Int?
    public var isSaving: Bool
    public var error: BloodPressureError?
    public var showDeleteConfirm: Bool

    // The twelve properties are Kotlin's twelve (`BloodPressureEditorUiState.kt:17-30`); the
    // memberwise initializer mirrors them one for one, which is what puts it past the limit.
    // swiftlint:disable:next function_default_parameter_at_end
    public init(
        isNew: Bool = true,
        systolicText: String = "",
        diastolicText: String = "",
        pulseText: String = "",
        suggestedSystolic: Double = BloodPressureEditorUiState.defaultSuggestedSystolic,
        suggestedDiastolic: Double = BloodPressureEditorUiState.defaultSuggestedDiastolic,
        suggestedPulse: Double = BloodPressureEditorUiState.defaultSuggestedPulse,
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
        self.suggestedSystolic = suggestedSystolic
        self.suggestedDiastolic = suggestedDiastolic
        self.suggestedPulse = suggestedPulse
        self.noteText = noteText
        self.dateEpochDay = dateEpochDay
        self.isSaving = isSaving
        self.error = error
        self.showDeleteConfirm = showDeleteConfirm
    }

    /// `BloodPressureEditorUiState.kt:31`.
    public var hasSystolic: Bool {
        !systolicText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// `BloodPressureEditorUiState.kt:33`.
    public var hasDiastolic: Bool {
        !diastolicText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// `BloodPressureEditorUiState.kt:35`.
    public var saveEnabled: Bool { !isSaving && hasSystolic && hasDiastolic }

    /// Where each stepper starts before anything is entered — suggestions, never values
    /// (`BloodPressureEditorUiState.kt:38-41`).
    public static let defaultSuggestedSystolic = 120.0
    public static let defaultSuggestedDiastolic = 80.0
    public static let defaultSuggestedPulse = 70.0
}

/// Everything the editor can ask the ViewModel to do (`BloodPressureEditorUiState.kt:43-62`).
public enum BloodPressureEditorEvent: Equatable, Sendable {
    case systolicChanged(String)
    case diastolicChanged(String)
    case pulseChanged(String)
    case noteChanged(String)
    case dateSelected(Int)
    case saveClicked
    /// Opens the confirmation; nothing is deleted until it is confirmed
    /// (`BloodPressureEditorUiState.kt:56-57`).
    case deleteClicked
    case deleteDismissed
    case deleteConfirmed
}
