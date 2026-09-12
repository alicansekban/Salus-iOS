// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/WeightEditorUiState.kt`.

import Foundation

/// What the weight editor draws (`WeightEditorUiState.kt:3-22`).
///
/// `valueText` is the weight the user entered, and only that: a new entry starts blank, with
/// ``suggestedKilograms`` shown as a dimmed suggestion in the stepper. Typing a value or nudging
/// the suggestion fills `valueText` in, which is what ``hasValue`` — and therefore Save — waits
/// for. An edit starts with the stored weight, so it is a value from the first frame
/// (`WeightEditorUiState.kt:3-8`).
///
/// The date is an `epochDay`, never a `Date`: it is a calendar day the user picked, and the instant
/// it becomes is composed once, at save, by `resolveEditorMeasuredAt` (`CLAUDE.md`, the `LocalDate`
/// rule).
public struct WeightEditorUiState: Equatable, Sendable {
    public var isNew: Bool
    public var valueText: String
    public var suggestedKilograms: Double
    public var noteText: String
    public var dateEpochDay: Int?
    public var isSaving: Bool
    public var showInvalidWeight: Bool
    public var showDeleteConfirm: Bool

    public init(
        isNew: Bool = true,
        valueText: String = "",
        suggestedKilograms: Double = WeightEditorUiState.defaultSuggestedKilograms,
        noteText: String = "",
        dateEpochDay: Int? = nil,
        isSaving: Bool = false,
        showInvalidWeight: Bool = false,
        showDeleteConfirm: Bool = false
    ) {
        self.isNew = isNew
        self.valueText = valueText
        self.suggestedKilograms = suggestedKilograms
        self.noteText = noteText
        self.dateEpochDay = dateEpochDay
        self.isSaving = isSaving
        self.showInvalidWeight = showInvalidWeight
        self.showDeleteConfirm = showDeleteConfirm
    }

    /// `WeightEditorUiState.kt:19`.
    public var hasValue: Bool { !valueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// `WeightEditorUiState.kt:21`.
    public var saveEnabled: Bool { !isSaving && hasValue }

    /// Where a new weight starts before anything is entered — a suggestion, never a value
    /// (`WeightEditorUiState.kt:24-25`).
    ///
    /// Kotlin's file-private `const` is a `static` on the type here: Swift has no file-private
    /// top-level constant a defaulted parameter in the same file can reach without exposing it,
    /// and the number is part of the state's contract either way.
    public static let defaultSuggestedKilograms = 70.0
}

/// Everything the editor can ask the ViewModel to do (`WeightEditorUiState.kt:27-42`).
public enum WeightEditorEvent: Equatable, Sendable {
    case valueChanged(String)
    case noteChanged(String)
    case dateSelected(Int)
    case saveClicked
    /// Opens the confirmation; nothing is deleted until it is confirmed
    /// (`WeightEditorUiState.kt:36-37`).
    case deleteClicked
    case deleteDismissed
    case deleteConfirmed
}
