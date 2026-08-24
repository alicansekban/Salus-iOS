// Ported 1:1 from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/
// appointments/ui/editor/AppointmentEditorViewModel.kt`.
//
// `MutableStateFlow` + `update { it.copy(…) }` becomes an `@Observable` `state` mutated in place,
// and `viewModelScope.launch` becomes `Task { }` inside a `@MainActor` type — `WeightEditorViewModel`
// set both spellings, and this file follows them member for member.
//
// The `Channel<AppointmentEditorEffect>(BUFFERED)` has no twin. `@Observable` publishes properties,
// not streams, so the effect is a `pendingEffect` the Route reads once through `consumeEffect()` —
// the pattern `ReminderHealthViewModel.swift:36, 90-93` established. One effect can be in flight at
// a time, which is all this screen ever produces: `addToCalendar` is a button tap that immediately
// presents a sheet.

import Foundation
import Observation
import SalusCommon
import SalusModel
import SalusNavigation
import SalusUI

/// Drives the appointment editor, new or existing (`AppointmentEditorViewModel.kt:29-188`).
@MainActor
@Observable
public final class AppointmentEditorViewModel {
    /// `AppointmentEditorViewModel.kt:38-39`.
    public private(set) var state: AppointmentEditorUiState

    /// The effect waiting for the view layer, or nil once it has been consumed
    /// (`AppointmentEditorViewModel.kt:41-42`).
    public private(set) var pendingEffect: AppointmentEditorEffect?

    private let appointmentId: String?
    private let repository: any AppointmentsRepository
    private let saveAppointment: SaveAppointmentUseCase
    private let clock: any SalusClock
    private let navigator: Navigator
    private let undoableDelete: UndoableDelete

    /// `AppointmentEditorViewModel.kt:44` — kept so "add to calendar" can span the appointment's
    /// own duration, which the form has no field for.
    private var loadedAppointment: Appointment?

    /// The existing appointment's load. Boxed so `deinit` can cancel it — see `CancellationBox`.
    private let loadTask = CancellationBox()

    public init(
        appointmentId: String?,
        repository: any AppointmentsRepository,
        saveAppointment: SaveAppointmentUseCase,
        clock: any SalusClock,
        navigator: Navigator,
        undoableDelete: UndoableDelete
    ) {
        self.appointmentId = appointmentId
        self.repository = repository
        self.saveAppointment = saveAppointment
        self.clock = clock
        self.navigator = navigator
        self.undoableDelete = undoableDelete
        state = AppointmentEditorUiState(isNew: appointmentId == nil)

        // `AppointmentEditorViewModel.kt:46-72`.
        guard let appointmentId else {
            state.dateEpochDay = clock.todayEpochDay()
            state.selectedOffsets = [ReminderOffsets.oneDay]
            return
        }
        loadTask.replace(with: Task { [weak self] in
            guard
                let self,
                let appointment = try? await repository.getAppointment(id: appointmentId)
            else {
                return
            }
            loadedAppointment = appointment
            state.isNew = false
            state.titleText = appointment.title
            state.doctorText = appointment.doctorName ?? ""
            state.locationText = appointment.location ?? ""
            state.notesText = appointment.notes ?? ""
            state.dateEpochDay = appointment.startsAt.date.epochDay
            // Kotlin splits the stored `LocalTime` back into `hour * 60 + minute`
            // (`AppointmentEditorViewModel.kt:64-66`); `SalusModel.LocalDateTime` already stores the
            // minute of day the form speaks, so there is nothing to recombine.
            state.minuteOfDay = appointment.startsAt.minuteOfDay
            state.selectedOffsets = appointment.reminderOffsetsMinutes
        })
    }

    deinit {
        loadTask.cancel()
    }

    /// `AppointmentEditorViewModel.kt:76-110`.
    public func onEvent(_ event: AppointmentEditorEvent) {
        switch event {
        case let .titleChanged(text):
            state.titleText = text
            state.showMissingTitle = false

        case let .doctorChanged(text):
            state.doctorText = text

        case let .locationChanged(text):
            state.locationText = text

        case let .notesChanged(text):
            state.notesText = text

        case let .dateSelected(epochDay):
            state.dateEpochDay = epochDay
            state.showMissingDateTime = false

        case let .timeSelected(minuteOfDay):
            state.minuteOfDay = minuteOfDay
            state.showMissingDateTime = false

        case let .reminderOffsetToggled(offsetMinutes):
            toggleOffset(offsetMinutes)

        case .saveClicked:
            save()

        case .deleteClicked:
            state.showDeleteConfirm = true

        case .deleteDismissed:
            state.showDeleteConfirm = false

        case .deleteConfirmed:
            delete()

        case .addToCalendarClicked:
            addToCalendar()
        }
    }

    /// Hands over the effect the Route has not presented yet, exactly once
    /// (`Channel.receiveAsFlow()`'s "each element is delivered to one collector").
    public func consumeEffect() -> AppointmentEditorEffect? {
        defer { pendingEffect = nil }
        return pendingEffect
    }

    /// `AppointmentEditorViewModel.kt:112-122`.
    private func toggleOffset(_ offsetMinutes: Int) {
        if let index = state.selectedOffsets.firstIndex(of: offsetMinutes) {
            state.selectedOffsets.remove(at: index)
        } else {
            state.selectedOffsets.append(offsetMinutes)
        }
        state.selectedOffsets.sort()
    }

    /// `AppointmentEditorViewModel.kt:124-149`.
    ///
    /// The form is read *before* the task starts, as Kotlin reads `_state.value` before `launch`:
    /// what is saved is what was on screen when the button was tapped.
    private func save() {
        let current = state
        Task { [weak self] in
            guard let self else { return }
            state.isSaving = true
            do {
                let result = try await saveAppointment(
                    existingId: appointmentId,
                    title: current.titleText,
                    doctorName: current.doctorText,
                    location: current.locationText,
                    notes: current.notesText,
                    dateEpochDay: current.dateEpochDay,
                    minuteOfDay: current.minuteOfDay,
                    reminderOffsetsMinutes: current.selectedOffsets
                )
                switch result {
                case .saved:
                    navigator.pop()

                case .missingTitle:
                    state.isSaving = false
                    state.showMissingTitle = true

                case .missingDateTime:
                    state.isSaving = false
                    state.showMissingDateTime = true
                }
            } catch {
                // No Kotlin twin, and the same arm `WeightEditorViewModel.save()` grew for the same
                // reason: the iOS repository declares `throws`, so a write failure can reach here
                // rather than ending quietly. The editor stays open with its text intact and the
                // button re-enabled, which is the only thing the user can act on.
                state.isSaving = false
            }
        }
    }

    /// `AppointmentEditorViewModel.kt:151-159`.
    private func delete() {
        guard let appointmentId else { return }
        state.showDeleteConfirm = false
        // The write is held for the undo window by an app-scoped controller, so popping this editor
        // — and with it this ViewModel — does not cancel it.
        undoableDelete(appointmentId, message: AppointmentsStrings.deleted) { [repository] in
            // Swallowed exactly as the detail screen swallows it: the commit runs after the editor
            // is gone, so there is nothing left to tell and nobody to act on it.
            try? await repository.deleteAppointment(id: appointmentId)
        }
        navigator.pop()
    }

    /// `AppointmentEditorViewModel.kt:161-187`.
    ///
    /// The zone is read here rather than captured, for `AppointmentDetailViewModel`'s reason: a
    /// wall-clock start has to be resolved with the zone that is current *now*.
    private func addToCalendar() {
        guard let dateEpochDay = state.dateEpochDay, let minuteOfDay = state.minuteOfDay else { return }
        let startsAt = LocalDateTime(date: LocalDate(epochDay: dateEpochDay), minuteOfDay: minuteOfDay)
        let start = startsAt.instant(in: clock.timeZone())
        let durationMinutes = loadedAppointment?.durationMinutes ?? Appointment.defaultDurationMinutes
        pendingEffect = .addToCalendar(
            CalendarEventDraft.forEditor(
                title: state.titleText,
                doctorText: state.doctorText,
                notesText: state.notesText,
                locationText: state.locationText,
                start: start,
                end: start.addingTimeInterval(TimeInterval(durationMinutes * 60))
            )
        )
    }
}
