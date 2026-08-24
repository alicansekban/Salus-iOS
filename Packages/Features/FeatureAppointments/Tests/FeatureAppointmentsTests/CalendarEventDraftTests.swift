// No Kotlin twin file. Android builds the calendar payload inline in the screen
// (`AppointmentDetailScreen.kt:377-388`) and asserts nothing about it, because an `Intent`'s extras
// are only observable once another app receives them. The iOS payload is a plain value the sheet
// is handed, so the two things Android leaves untested — *which* text becomes the description, and
// that the event spans the appointment's duration — are pinned here.
//
// The first is divergence (d) in the global constraints: the detail screen sends the notes alone,
// the editor sends `doctor + "\n" + notes`. They differ on Android and the port keeps them
// differing, so a test that says "detail carries the notes and nothing else" is what stops the two
// builders from being quietly merged.

import Foundation
import SalusCommon
import SalusModel
import SalusTesting
import Testing

@testable import FeatureAppointments

@Suite("CalendarEventDraft")
struct CalendarEventDraftTests {
    private static let zone = FixedSalusClock.defaultZone
    private static let startsAt = LocalDateTime(
        date: LocalDate(year: 2026, month: 8, day: 18),
        minuteOfDay: 10 * 60
    )

    private func appointment(notes: String?) -> Appointment {
        Appointment(
            id: "a1",
            title: "Annual check-up",
            doctorName: "Dr. Lee",
            specialty: "Cardiology",
            location: "City Clinic",
            notes: notes,
            startsAt: Self.startsAt,
            timeZone: Self.zone,
            durationMinutes: 30,
            status: .scheduled,
            reminderOffsetsMinutes: []
        )
    }

    /// `AppointmentDetailScreen.kt:380-382` — title, description and location, in that order, and
    /// the description is `appointment.notes` alone.
    @Test("the detail draft describes the event with the appointment's notes alone")
    func theDetailDraftDescribesTheEventWithTheAppointmentsNotesAlone() {
        let start = Self.startsAt.instant(in: Self.zone)
        let draft = CalendarEventDraft.forDetail(
            appointment: appointment(notes: "Bring blood test results"),
            start: start,
            end: start.addingTimeInterval(30 * 60)
        )

        #expect(draft.title == "Annual check-up")
        #expect(draft.notes == "Bring blood test results")
        // The doctor's name is the editor's payload, never the detail screen's — divergence (d).
        #expect(draft.notes?.contains("Dr. Lee") == false)
        #expect(draft.location == "City Clinic")
    }

    /// `AppointmentDetailScreen.kt:383-384` + `AppointmentDetailViewModel.kt:44-48` — the event
    /// begins at the wall-clock start read in the current zone and lasts `durationMinutes`.
    @Test("the detail draft spans the appointment's duration")
    func theDetailDraftSpansTheAppointmentsDuration() {
        let appointment = appointment(notes: nil)
        let start = appointment.startsAt.instant(in: Self.zone)
        let end = Date(epochMilliseconds: start.epochMilliseconds + Int64(appointment.durationMinutes) * 60000)

        let draft = CalendarEventDraft.forDetail(appointment: appointment, start: start, end: end)

        #expect(draft.notes == nil)
        #expect(draft.start == start)
        #expect(draft.end.timeIntervalSince(draft.start) == 30 * 60)
    }

    /// `AppointmentEditorViewModel.kt:161-176` — the editor's payload is built from the *typed*
    /// fields, so the doctor's name reaches the calendar even before it has been saved. Divergence
    /// (d): this is the builder the detail screen deliberately does not share.
    @Test("the editor draft describes the event with the doctor and the notes")
    func theEditorDraftDescribesTheEventWithTheDoctorAndTheNotes() {
        let start = Self.startsAt.instant(in: Self.zone)

        let draft = CalendarEventDraft.forEditor(
            title: "  Annual check-up  ",
            doctorText: " Dr. Lee ",
            notesText: "Bring blood test results",
            locationText: "  City Clinic ",
            start: start,
            end: start.addingTimeInterval(30 * 60)
        )

        #expect(draft.title == "Annual check-up")
        #expect(draft.notes == "Dr. Lee\nBring blood test results")
        #expect(draft.location == "City Clinic")

        // `takeIf { it.isNotEmpty() }` on both: a form the user left alone proposes no description
        // and no location rather than an empty one.
        let blank = CalendarEventDraft.forEditor(
            title: "Annual check-up",
            doctorText: "  ",
            notesText: "",
            locationText: " ",
            start: start,
            end: start.addingTimeInterval(30 * 60)
        )

        #expect(blank.notes == nil)
        #expect(blank.location == nil)
    }
}
