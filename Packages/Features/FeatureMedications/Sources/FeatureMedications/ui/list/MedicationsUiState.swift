// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/ui/list/MedicationsUiState.kt`.
//
// `ImmutableList` is dropped rather than imitated — a Swift `Array` in a `struct` already is what
// `kotlinx.collections.immutable` promises Compose (`ChartUiModel.swift`, `VitalsUiState.swift` and
// `AppointmentsUiState.swift` record the same ruling).
//
// ONE FIELD IS RENAMED, and the rename is decision 1 rather than taste: Kotlin's old field name
// counts TAKEN doses against the occurrences its generator expands, while this port's
// ``RecordedDoseRatio`` counts TAKEN against what was RECORDED — a different number, whose name
// must not claim the old one (`RecordedDoseRatio.swift:1-13`, spec 7 and 12). Android owes the
// mirror change.

/// One row of the list (`MedicationsUiState.kt:8-13`).
///
/// `Identifiable` is what `items(items, key = { it.medication.id })` (`MedicationsScreen.kt:160`)
/// asks for on Android; `ForEach` asks for it here.
public struct MedicationListItem: Equatable, Hashable, Sendable, Identifiable {
    public let medication: Medication
    public let schedules: [MedicationSchedule]

    /// Doses recorded as taken over the last 7 days, as a share of the doses recorded at all,
    /// 0…100; nil when nothing was recorded yet (`MedicationsUiState.kt:11`, re-based).
    ///
    /// Never 0 for "nothing recorded": an absent record is not a dose someone did not take, and
    /// drawing it as 0% would say it was.
    public let recordedDosePercent: Int?

    public var id: String { medication.id }

    public init(medication: Medication, schedules: [MedicationSchedule], recordedDosePercent: Int?) {
        self.medication = medication
        self.schedules = schedules
        self.recordedDosePercent = recordedDosePercent
    }
}

/// What the medications list draws (`MedicationsUiState.kt:15-20`).
public struct MedicationsUiState: Equatable, Sendable {
    public var isLoading: Bool
    public var medications: [MedicationListItem]

    /// The medication whose delete confirmation is open; nil when none is
    /// (`MedicationsUiState.kt:19`).
    ///
    /// The medication itself rather than its id, so the dialog can put the name in its question
    /// without looking it up again — exactly what Kotlin's `pendingDelete` carries.
    public var pendingDelete: Medication?

    public init(
        isLoading: Bool = true,
        medications: [MedicationListItem] = [],
        pendingDelete: Medication? = nil
    ) {
        self.isLoading = isLoading
        self.medications = medications
        self.pendingDelete = pendingDelete
    }
}

/// Everything the screen can ask the ViewModel to do (`MedicationsUiState.kt:22-29`).
public enum MedicationsEvent: Equatable, Sendable {
    /// Opens the confirmation for the row's trash icon; nothing is deleted until confirmed
    /// (`MedicationsUiState.kt:23-24`).
    case deleteRequested(String)

    /// `MedicationsUiState.kt:26`.
    case deleteDismissed

    /// `MedicationsUiState.kt:28`.
    case deleteConfirmed
}
