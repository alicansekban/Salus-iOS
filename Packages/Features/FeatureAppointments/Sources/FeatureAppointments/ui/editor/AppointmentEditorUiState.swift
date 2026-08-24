// Ported 1:1 from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/
// appointments/ui/editor/AppointmentEditorUiState.kt`.
//
// Kotlin's `ImmutableList<Int>` becomes `[Int]`: a Swift `Array` is already a value type, so the
// recomposition-stability problem `kotlinx.collections.immutable` exists to solve does not arise
// here — `AppointmentsUiState` recorded that ruling first.
//
// The effect is the one shape difference. Kotlin sends `AddToCalendar` through a
// `Channel(BUFFERED)`; `@Observable` has no channel, so the ViewModel publishes a `pendingEffect`
// the Route consumes exactly once — the pattern `ReminderHealthViewModel` set. What travels is a
// `CalendarEventDraft` rather than the five loose `Intent` extras, because the sheet that receives
// it takes a draft (divergence (e)).

import Foundation

/// Selectable reminder offsets, minutes before the appointment, offered in the editor
/// (`AppointmentEditorUiState.kt:6-13`).
public enum ReminderOffsets {
    public static let oneHour = 60
    public static let oneDay = 24 * 60
    public static let oneWeek = 7 * 24 * 60

    /// The three presets, in the order the chip row draws them (`AppointmentEditorUiState.kt:12`).
    public static let options = [oneHour, oneDay, oneWeek]
}

/// What the editor draws (`AppointmentEditorUiState.kt:15-28`).
public struct AppointmentEditorUiState: Equatable, Sendable {
    public var isNew: Bool
    public var titleText: String
    public var doctorText: String
    public var locationText: String
    public var notesText: String
    /// Days since 1970-01-01; nil only until the create-mode default or the loaded appointment
    /// lands (`AppointmentEditorUiState.kt:21`).
    public var dateEpochDay: Int?
    /// Minutes since local midnight; nil until the user picks a time on a new appointment
    /// (`AppointmentEditorUiState.kt:22`).
    public var minuteOfDay: Int?
    /// Ascending, and kept that way by every toggle (`AppointmentEditorUiState.kt:23`).
    public var selectedOffsets: [Int]
    public var isSaving: Bool
    public var showMissingTitle: Bool
    public var showMissingDateTime: Bool
    public var showDeleteConfirm: Bool

    public init(
        isNew: Bool = true,
        titleText: String = "",
        doctorText: String = "",
        locationText: String = "",
        notesText: String = "",
        dateEpochDay: Int? = nil,
        minuteOfDay: Int? = nil,
        selectedOffsets: [Int] = [],
        isSaving: Bool = false,
        showMissingTitle: Bool = false,
        showMissingDateTime: Bool = false,
        showDeleteConfirm: Bool = false
    ) {
        self.isNew = isNew
        self.titleText = titleText
        self.doctorText = doctorText
        self.locationText = locationText
        self.notesText = notesText
        self.dateEpochDay = dateEpochDay
        self.minuteOfDay = minuteOfDay
        self.selectedOffsets = selectedOffsets
        self.isSaving = isSaving
        self.showMissingTitle = showMissingTitle
        self.showMissingDateTime = showMissingDateTime
        self.showDeleteConfirm = showDeleteConfirm
    }
}

/// Everything the editor can ask the ViewModel to do (`AppointmentEditorUiState.kt:30-55`).
public enum AppointmentEditorEvent: Equatable, Sendable {
    case titleChanged(String)
    case doctorChanged(String)
    case locationChanged(String)
    case notesChanged(String)
    case dateSelected(Int)
    case timeSelected(Int)
    case reminderOffsetToggled(Int)
    case saveClicked
    /// Opens the confirmation; nothing is deleted until it is confirmed.
    case deleteClicked
    case deleteDismissed
    case deleteConfirmed
    case addToCalendarClicked
}

/// The one thing the editor asks the *view layer* to do (`AppointmentEditorUiState.kt:57-66`).
///
/// Never navigation: `Navigator` already carries that, and the ViewModel calls it directly.
public enum AppointmentEditorEffect: Equatable, Sendable {
    /// Present the system's event editor, prefilled from the typed fields.
    case addToCalendar(CalendarEventDraft)
}
