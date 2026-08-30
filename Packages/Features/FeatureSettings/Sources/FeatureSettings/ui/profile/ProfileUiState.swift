// Ported 1:1 from `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/
// ui/profile/ProfileUiState.kt`.
//
// The three UDF types keep their Kotlin names and their Kotlin job. There is no `ProfileEffect` on
// either platform: closing after a save is a `Navigator.pop()` from the ViewModel, never an effect
// (`ProfileUiState.kt:73-74`).

import SalusCommon
import SalusModel

/// The profile editor: the same five fields onboarding collects, in the same order, editable at any
/// later time (`ProfileUiState.kt:6-11`).
///
/// Weight is deliberately absent — it is a vitals time series, not a profile attribute.
public struct ProfileUiState: Sendable, Equatable {
    public var isLoading: Bool
    public var name: String
    public var sex: Sex?
    public var birthDateEpochDay: Int?
    public var heightText: String
    public var healthNotes: String
    /// The sex on disk, so the screen can tell whether the pending value changes anything
    /// (`ProfileUiState.kt:18-19`).
    public var storedSex: Sex?
    public var isSaving: Bool
    /// Set when the pending sex would hide the Cycle row and the user has not confirmed yet
    /// (`ProfileUiState.kt:21-22`).
    public var showSexChangeConfirm: Bool

    public init(
        isLoading: Bool = true,
        name: String = "",
        sex: Sex? = nil,
        birthDateEpochDay: Int? = nil,
        heightText: String = "",
        healthNotes: String = "",
        storedSex: Sex? = nil,
        isSaving: Bool = false,
        showSexChangeConfirm: Bool = false
    ) {
        self.isLoading = isLoading
        self.name = name
        self.sex = sex
        self.birthDateEpochDay = birthDateEpochDay
        self.heightText = heightText
        self.healthNotes = healthNotes
        self.storedSex = storedSex
        self.isSaving = isSaving
        self.showSexChangeConfirm = showSexChangeConfirm
    }

    /// Blank is fine (the field is optional); only a typed value outside the range is wrong
    /// (`ProfileUiState.kt:24-26`).
    public var showInvalidHeight: Bool {
        !heightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && MeasurementInput.parseHeightCm(heightText) == nil
    }

    /// The only rule that decides whether the Cycle row exists — the same one the More screen
    /// applies (`sex != .male`). Comparing raw sex values would miss `nil → male` and nag on
    /// `female → other`, which changes nothing (`ProfileUiState.kt:28-42`).
    public var cycleVisibilityChange: CycleVisibilityChange? {
        let before = Self.showsCycle(storedSex)
        let after = Self.showsCycle(sex)
        if before == after {
            return nil
        }
        return after ? .appears : .disappears
    }

    /// `ProfileUiState.kt:44` — a skipped answer counts as showing.
    private static func showsCycle(_ sex: Sex?) -> Bool {
        sex != .male
    }
}

/// What the pending sex does to the Cycle row. Nothing is ever deleted either way
/// (`ProfileUiState.kt:47-51`).
public enum CycleVisibilityChange: Sendable, Equatable {
    case appears
    case disappears
}

/// `ProfileUiState.kt:53-71`.
public enum ProfileEvent: Sendable, Equatable {
    case nameChanged(String)
    case sexSelected(Sex)
    case birthDateSelected(Int)
    case heightChanged(String)
    case healthNotesChanged(String)
    case saveClicked
    /// The user accepted that the Cycle row disappears; the save goes through.
    case sexChangeConfirmed
    /// The user backed out; the stored sex is put back and nothing is written.
    case sexChangeDismissed
}
