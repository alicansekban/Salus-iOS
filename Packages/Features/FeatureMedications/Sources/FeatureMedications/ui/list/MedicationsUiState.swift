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

    /// Today's chip. Nil when the day holds no dose slot for this medication
    /// (`MedicationsUiState.kt:19-20`).
    public let dayStatus: MedicationDayStatus?

    /// The earliest of today's unrecorded doses; what the card prints under the name
    /// (`MedicationsUiState.kt:21-22`).
    public let nextDoseMinuteOfDay: Int?

    /// Set while a dose of today is unrecorded and its time has passed — the "take now" button
    /// (`MedicationsUiState.kt:23-24`).
    public let dueDose: PendingDose?

    public var id: String { medication.id }

    public init(
        medication: Medication,
        schedules: [MedicationSchedule],
        recordedDosePercent: Int?,
        dayStatus: MedicationDayStatus? = nil,
        nextDoseMinuteOfDay: Int? = nil,
        dueDose: PendingDose? = nil
    ) {
        self.medication = medication
        self.schedules = schedules
        self.recordedDosePercent = recordedDosePercent
        self.dayStatus = dayStatus
        self.nextDoseMinuteOfDay = nextDoseMinuteOfDay
        self.dueDose = dueDose
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

    /// Earliest unrecorded dose of today across every medication; nil when none is left
    /// (`MedicationsUiState.kt:32-33`).
    public var nextDoseMinuteOfDay: Int?

    /// Today, for the header's date. It comes from the view model's `SalusClock` rather than from
    /// the view, because a screen is never allowed to ask the machine what day it is
    /// (`MedicationsUiState.kt:34-38`).
    public var todayEpochDay: Int

    public init(
        isLoading: Bool = true,
        medications: [MedicationListItem] = [],
        pendingDelete: Medication? = nil,
        nextDoseMinuteOfDay: Int? = nil,
        todayEpochDay: Int = 0
    ) {
        self.isLoading = isLoading
        self.medications = medications
        self.pendingDelete = pendingDelete
        self.nextDoseMinuteOfDay = nextDoseMinuteOfDay
        self.todayEpochDay = todayEpochDay
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

    /// The card's inline "take now". Goes through the same use case as the notification action, so
    /// the list is not a second write path — only a second button on the first one
    /// (`MedicationsUiState.kt:49-53`).
    case takeDoseClicked(PendingDose)
}
