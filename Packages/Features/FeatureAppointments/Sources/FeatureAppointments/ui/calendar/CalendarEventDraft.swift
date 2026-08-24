// The twin of the `Intent(ACTION_INSERT)` extras Android fills in
// (`AppointmentDetailScreen.kt:377-388`, `AppointmentEditorScreen.kt`'s
// `AppointmentEditorEffect.AddToCalendar`) — recorded as divergence (e): iOS has no
// "hand a payload to whichever app answers" mechanism, so the payload becomes a value and
// `EKEventEditViewController` is what receives it.
//
// Deliberately free of EventKit. This is what both screens *build*; `CalendarEventEditSheet` is
// the only file that knows what an `EKEvent` is, which is what lets the whole feature — this type
// included — compile and be tested on the macOS host `swift test` runs on.

import Foundation

/// A calendar event the user has not agreed to yet: the fields prefilled into the system's event
/// editor, which is where the event is actually created.
public struct CalendarEventDraft: Equatable, Sendable {
    public let title: String
    /// `CalendarContract.Events.DESCRIPTION`. **What goes in here differs by screen, on purpose**
    /// — divergence (d): the detail screen sends `appointment.notes` alone, and the editor sends
    /// the doctor's name and the notes joined by a newline, because the editor's fields are the
    /// only place the doctor has been typed but not yet saved. Each screen therefore has its own
    /// builder below rather than one that guesses.
    public let notes: String?
    public let location: String?
    public let start: Date
    public let end: Date

    public init(title: String, notes: String?, location: String?, start: Date, end: Date) {
        self.title = title
        self.notes = notes
        self.location = location
        self.start = start
        self.end = end
    }
}

extension CalendarEventDraft {
    /// The detail screen's payload (`AppointmentDetailScreen.kt:379-386`).
    ///
    /// - Parameters:
    ///   - start: `EXTRA_EVENT_BEGIN_TIME`, the wall-clock start resolved in the zone that is
    ///     current now — `AppointmentDetailUiState.startEpochMs`, which the ViewModel derives.
    ///   - end: `EXTRA_EVENT_END_TIME`, that start plus `durationMinutes`.
    public static func forDetail(appointment: Appointment, start: Date, end: Date) -> CalendarEventDraft {
        CalendarEventDraft(
            title: appointment.title,
            notes: appointment.notes,
            location: appointment.location,
            start: start,
            end: end
        )
    }

    /// The editor's payload (`AppointmentEditorViewModel.kt:161-187`).
    ///
    /// Built from the *typed* fields, not from the stored appointment: the doctor's name and the
    /// notes may never have been saved, and proposing an event is something the user can do before
    /// saving. That is also why this builder joins the doctor to the notes where ``forDetail(...)``
    /// sends the notes alone — divergence (d), which the two platforms share.
    ///
    /// - Parameters:
    ///   - start: `EXTRA_EVENT_BEGIN_TIME`, the form's day and time resolved in the zone that is
    ///     current now.
    ///   - end: `EXTRA_EVENT_END_TIME`, that start plus the appointment's `durationMinutes` (60 for
    ///     one that does not exist yet).
    public static func forEditor(
        title: String,
        doctorText: String,
        notesText: String,
        locationText: String,
        start: Date,
        end: Date
    ) -> CalendarEventDraft {
        CalendarEventDraft(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            // `listOf(doctor, notes).map { it.trim() }.filter { it.isNotEmpty() }
            // .joinToString("\n").takeIf { it.isNotEmpty() }` (`AppointmentEditorViewModel.kt:172-176`).
            notes: nonBlank(
                [doctorText, notesText]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
            ),
            location: nonBlank(locationText.trimmingCharacters(in: .whitespacesAndNewlines)),
            start: start,
            end: end
        )
    }
}
