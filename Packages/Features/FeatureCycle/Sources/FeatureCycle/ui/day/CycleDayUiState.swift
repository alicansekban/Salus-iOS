// Ported 1:1 from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/
// ui/day/CycleDayUiState.kt`.
//
// Kotlin's `ImmutableList<CycleSymptomUi>` becomes `[CycleSymptomUi]`: a Swift `Array` is already a
// value type, so the recomposition-stability problem `kotlinx.collections.immutable` exists to
// solve does not arise here — `MedicationsUiState` recorded that ruling first and `CycleUiState`
// follows it.
//
// `CycleSymptomUi.isSelected` is a `var` where Kotlin has `val` + `copy(isSelected = …)`: the one
// event that changes a row rewrites exactly that field, and a memberwise re-construction at each
// call site would bury it under the two that never change. `id` and `nameKey` stay `let` — a row's
// identity and its label key are fixed the moment the catalog is read.

import SalusModel

/// One symptom chip: a catalog entry plus whether this day has it (`CycleDayUiState.kt:8-12`).
///
/// `Identifiable` so `ForEach` keys on the catalog id rather than on the whole row; the chip's
/// selection flips on every tap, and a `\.self` key would rebuild the chip instead of updating it.
public struct CycleSymptomUi: Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    /// A stable string-resource key (`"cramps"`), resolved by `CycleStrings.symptomLabel(nameKey:)`.
    public let nameKey: String
    public var isSelected: Bool

    public init(id: String, nameKey: String, isSelected: Bool) {
        self.id = id
        self.nameKey = nameKey
        self.isSelected = isSelected
    }
}

/// What the day-log screen draws (`CycleDayUiState.kt:14-22`).
///
/// Every default is Kotlin's, `isLoading = true` included: the screen opens on a spinner and the
/// catalog replaces it, so an empty catalog never flashes as "no symptoms".
public struct CycleDayUiState: Equatable, Sendable {
    public var isLoading: Bool
    public var epochDay: Int
    public var symptoms: [CycleSymptomUi]
    public var flow: FlowLevel?
    public var mood: Mood?
    public var noteText: String
    public var isSaving: Bool

    public init(
        isLoading: Bool = true,
        epochDay: Int = 0,
        symptoms: [CycleSymptomUi] = [],
        flow: FlowLevel? = nil,
        mood: Mood? = nil,
        noteText: String = "",
        isSaving: Bool = false
    ) {
        self.isLoading = isLoading
        self.epochDay = epochDay
        self.symptoms = symptoms
        self.flow = flow
        self.mood = mood
        self.noteText = noteText
        self.isSaving = isSaving
    }
}

/// Everything the day-log screen can ask the ViewModel to do (`CycleDayUiState.kt:24-34`).
public enum CycleDayEvent: Equatable, Sendable {
    case symptomToggled(String)
    case flowSelected(FlowLevel)
    case moodSelected(Mood)
    case noteChanged(String)
    case saveClicked
}
