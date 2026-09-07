// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/ui/editor/MedicationEditorUiState.kt`.
//
// Kotlin's `ImmutableList<DoseTimeUi>` becomes `[DoseTimeUi]`: a Swift `Array` is already a value
// type, so the recomposition-stability problem `kotlinx.collections.immutable` exists to solve does
// not arise here — `MedicationsUiState` recorded that ruling first.
//
// `DoseTimeUi`'s two mutable fields are `var` where Kotlin has `val` + `copy(…)`. The two events
// that change a row (`doseTimeChanged`, `doseAmountChanged`) rewrite exactly one field, and a
// memberwise re-construction at each call site would bury it under the two that do not.
// `existingScheduleId` stays `let`: a row's identity is fixed the moment it is built.

import SalusModel
import SalusReminder

/// One dose time row in the builder; "3× a day" = three rows = three schedule entities
/// (`MedicationEditorUiState.kt:8-14`).
public struct DoseTimeUi: Equatable, Hashable, Sendable {
    /// nil for a row added in this editing session (`MedicationEditorUiState.kt:10`).
    public let existingScheduleId: String?
    public var minuteOfDay: Int
    public var amountInput: String

    public init(existingScheduleId: String?, minuteOfDay: Int, amountInput: String) {
        self.existingScheduleId = existingScheduleId
        self.minuteOfDay = minuteOfDay
        self.amountInput = amountInput
    }
}

/// What the form got wrong, one at a time (`MedicationEditorUiState.kt:16-22`).
///
/// The five cases are `SaveMedicationUseCase.Result`'s five failures, and the screen draws each as
/// its `editor_error_*` string.
public enum EditorError: Equatable, Sendable {
    case emptyName
    case noDoseTimes
    case invalidInterval
    case noDaysSelected
    case endBeforeStart
}

/// What the editor draws (`MedicationEditorUiState.kt:24-42`).
///
/// Every default is Kotlin's, `intervalDaysInput`'s `"2"` included: an interval schedule that is
/// selected and never touched is "every other day" rather than a form that refuses to save.
public struct MedicationEditorUiState: Equatable, Sendable {
    public var isLoading: Bool
    public var isNew: Bool
    public var name: String
    public var form: MedicationForm
    public var strengthValueInput: String
    public var strengthUnitInput: String
    public var instructions: String
    public var stockCountInput: String
    public var stockThresholdInput: String
    public var startDateEpochDay: Int
    public var endDateEpochDay: Int?
    public var recurrence: Recurrence
    /// bit 0 = Monday .. bit 6 = Sunday (`MedicationEditorUiState.kt:37`).
    public var daysOfWeekMask: Int
    public var intervalDaysInput: String
    public var doseTimes: [DoseTimeUi]
    public var error: EditorError?
    public var showDeleteConfirm: Bool
    /// The hard problems behind a save that succeeded on a device where the dose alarm cannot reach
    /// the user — nil until such a save, and empty never
    /// (`ReminderReadinessReport.hardProblems` is non-empty exactly when the report is `broken`).
    /// The editor stays open behind the dialog it drives; both answers close it.
    public var reminderWarning: [ReminderProblem]?

    public init(
        isLoading: Bool = true,
        isNew: Bool = true,
        name: String = "",
        form: MedicationForm = .tablet,
        strengthValueInput: String = "",
        strengthUnitInput: String = "",
        instructions: String = "",
        stockCountInput: String = "",
        stockThresholdInput: String = "",
        startDateEpochDay: Int = 0,
        endDateEpochDay: Int? = nil,
        recurrence: Recurrence = .daily,
        daysOfWeekMask: Int = 0,
        intervalDaysInput: String = "2",
        doseTimes: [DoseTimeUi] = [],
        error: EditorError? = nil,
        showDeleteConfirm: Bool = false,
        reminderWarning: [ReminderProblem]? = nil
    ) {
        self.isLoading = isLoading
        self.isNew = isNew
        self.name = name
        self.form = form
        self.strengthValueInput = strengthValueInput
        self.strengthUnitInput = strengthUnitInput
        self.instructions = instructions
        self.stockCountInput = stockCountInput
        self.stockThresholdInput = stockThresholdInput
        self.startDateEpochDay = startDateEpochDay
        self.endDateEpochDay = endDateEpochDay
        self.recurrence = recurrence
        self.daysOfWeekMask = daysOfWeekMask
        self.intervalDaysInput = intervalDaysInput
        self.doseTimes = doseTimes
        self.error = error
        self.showDeleteConfirm = showDeleteConfirm
        self.reminderWarning = reminderWarning
    }
}

/// Everything the editor can ask the ViewModel to do (`MedicationEditorUiState.kt:44-69`).
public enum MedicationEditorEvent: Equatable, Sendable {
    case nameChanged(String)
    case formSelected(MedicationForm)
    case strengthValueChanged(String)
    case strengthUnitChanged(String)
    case instructionsChanged(String)
    case stockCountChanged(String)
    case stockThresholdChanged(String)
    case startDateSelected(epochDay: Int)
    case endDateSelected(epochDay: Int?)
    case recurrenceSelected(Recurrence)
    case dayOfWeekToggled(mondayBasedIndex: Int)
    case intervalDaysChanged(String)
    case doseTimeAdded(minuteOfDay: Int)
    case doseTimeChanged(index: Int, minuteOfDay: Int)
    case doseAmountChanged(index: Int, value: String)
    case doseTimeRemoved(index: Int)
    case saveClicked
    /// Opens the confirmation; nothing is deleted until it is confirmed
    /// (`MedicationEditorUiState.kt:62-63`).
    case deleteClicked
    case deleteDismissed
    case deleteConfirmed
    /// "Fix" on the post-save warning: asks the shell for Reminder health, and leaves closing the
    /// editor to the shell too — see ``MedicationEditorEffect/openReminderHealth``.
    case reminderWarningFixClicked
    /// "Not now" on the post-save warning, and the alert's own system-driven dismissal: closes the
    /// editor and changes nothing else.
    case reminderWarningDismissed
}

/// What the editor asks the shell to do — a hop it cannot make itself, because the destination
/// belongs to another feature (`MedicationEditorUiState.kt`'s `MedicationEditorEffect`).
///
/// Kotlin's `Channel.BUFFERED`; here the queue is
/// ``MedicationEditorViewModel/pendingEffects``, drained by ``MedicationEditorViewModel/
/// consumeEffects()`` — the `MoreViewModel` shape, which records why an `@Observable` needs one.
public enum MedicationEditorEffect: Equatable, Sendable {
    /// Reminder health lives in `:feature:settings`, and features never depend on each other: the
    /// shell pops the editor and pushes `ReminderHealthKey` on the Route's behalf, in that order,
    /// so Back from Reminder health lands on the medication list. Both halves are the shell's
    /// because the ViewModel's own pop would tear down the Route draining this effect.
    case openReminderHealth
}
