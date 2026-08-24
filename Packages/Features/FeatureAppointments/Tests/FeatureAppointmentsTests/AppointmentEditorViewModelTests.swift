// Ported from `feature/appointments/src/test/kotlin/com/alicansekban/salus/feature/appointments/
// ui/editor/AppointmentEditorViewModelTest.kt` — all seven cases, by name, in the Kotlin order.
//
// The mechanical differences are the ones this target already settled for the detail suite:
// `MainDispatcherRule` has no twin — `@MainActor` on the suite is the whole mechanism;
// `advanceUntilIdle()` becomes `waitUntil`, a bounded yield loop, because Swift Testing has no
// virtual scheduler; and `advanceUntilIdle()` closing the undo window becomes
// `TestDeletes.closeUndoWindow()`, the gate `PendingDeleteController`'s injected `sleep` waits on.
//
// One further difference, in the last case: Turbine's `vm.effects.test { awaitItem() }` becomes
// reading `consumeEffect()`, because the iOS effect is a `pendingEffect` property rather than a
// `Channel` (`AppointmentEditorViewModel.swift` records why). The assertions are the same five
// fields, read off the `CalendarEventDraft` the effect carries instead of off `Intent` extras.

import Foundation
import SalusCommon
import SalusModel
import SalusNavigation
import SalusTesting
import SalusUI
import Testing

@testable import FeatureAppointments

@Suite("AppointmentEditorViewModel")
@MainActor
struct AppointmentEditorViewModelTests {
    /// `AppointmentEditorViewModelTest.kt:35-37` — the same zone and "now".
    private static let zone = FixedSalusClock.defaultZone
    /// `AppointmentEditorViewModelTest.kt:59` — the existing appointment's wall-clock start, which
    /// is also `20_700` / `630` read as a day and a minute of day.
    private static let startsAt = LocalDateTime(
        date: LocalDate(year: 2026, month: 9, day: 4),
        minuteOfDay: 10 * 60 + 30
    )

    private let clock = FixedSalusClock(
        now: Date(epochMilliseconds: 1_755_000_000_000),
        timeZone: AppointmentEditorViewModelTests.zone
    )
    private let repository = FakeAppointmentsRepository(zone: AppointmentEditorViewModelTests.zone)
    private let navigator = FakeNavigator()
    private let deletes = TestDeletes()

    /// `AppointmentEditorViewModelTest.kt:43-51`.
    private func viewModel(appointmentId: String? = nil) -> AppointmentEditorViewModel {
        AppointmentEditorViewModel(
            appointmentId: appointmentId,
            repository: repository,
            saveAppointment: SaveAppointmentUseCase(
                repository: repository,
                idGenerator: FixedIdGenerator(id: "new-id"),
                clock: clock
            ),
            clock: clock,
            navigator: navigator.navigator,
            undoableDelete: deletes.undoableDelete
        )
    }

    /// `AppointmentEditorViewModelTest.kt:53-65`.
    private func existing() -> Appointment {
        Appointment(
            id: "a1",
            title: "Dental checkup",
            doctorName: "Dr. X",
            specialty: nil,
            location: "Clinic A",
            notes: "notes",
            startsAt: Self.startsAt,
            timeZone: Self.zone,
            durationMinutes: 45,
            status: .scheduled,
            reminderOffsetsMinutes: [60, 1440]
        )
    }

    /// `AppointmentEditorViewModelTest.kt:67-77`.
    @Test("new editor defaults to today with one-day reminder preselected")
    func newEditorDefaultsToTodayWithOneDayReminderPreselected() {
        let viewModel = viewModel()

        let state = viewModel.state
        #expect(state.isNew)
        #expect(state.dateEpochDay == clock.todayEpochDay())
        #expect(state.minuteOfDay == nil)
        #expect(state.selectedOffsets == [ReminderOffsets.oneDay])
        navigator.stop()
    }

    /// `AppointmentEditorViewModelTest.kt:79-97`.
    @Test("saving a valid appointment stores it and pops the back stack")
    func savingAValidAppointmentStoresItAndPopsTheBackStack() async throws {
        let viewModel = viewModel()

        viewModel.onEvent(.titleChanged("Dental checkup"))
        viewModel.onEvent(.dateSelected(20700))
        viewModel.onEvent(.timeSelected(630))
        viewModel.onEvent(.reminderOffsetToggled(ReminderOffsets.oneHour))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }

        #expect(repository.current().count == 1)
        let saved = try #require(repository.current().first)
        #expect(saved.id == "new-id")
        #expect(saved.title == "Dental checkup")
        #expect(saved.startsAt == Self.startsAt)
        #expect(saved.reminderOffsetsMinutes == [ReminderOffsets.oneHour, ReminderOffsets.oneDay])
        navigator.stop()
    }

    /// `AppointmentEditorViewModelTest.kt:99-111`.
    @Test("missing title shows error and saves nothing")
    func missingTitleShowsErrorAndSavesNothing() async {
        let viewModel = viewModel()

        viewModel.onEvent(.dateSelected(20700))
        viewModel.onEvent(.timeSelected(630))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the missing-title error") { viewModel.state.showMissingTitle }

        #expect(viewModel.state.showMissingTitle)
        #expect(repository.current().isEmpty)
        navigator.stop()
    }

    /// `AppointmentEditorViewModelTest.kt:113-124`.
    @Test("missing time shows error and saves nothing")
    func missingTimeShowsErrorAndSavesNothing() async {
        let viewModel = viewModel()

        viewModel.onEvent(.titleChanged("Checkup"))
        viewModel.onEvent(.saveClicked)
        await waitUntil("the missing-date-time error") { viewModel.state.showMissingDateTime }

        #expect(viewModel.state.showMissingDateTime)
        #expect(repository.current().isEmpty)
        navigator.stop()
    }

    /// `AppointmentEditorViewModelTest.kt:126-142`.
    @Test("editing existing appointment preloads all fields")
    func editingExistingAppointmentPreloadsAllFields() async {
        repository.setAppointments(existing())

        let viewModel = viewModel(appointmentId: "a1")
        await waitUntil("the existing appointment to load") { viewModel.state.minuteOfDay != nil }

        let state = viewModel.state
        #expect(state.isNew == false)
        #expect(state.titleText == "Dental checkup")
        #expect(state.doctorText == "Dr. X")
        #expect(state.locationText == "Clinic A")
        #expect(state.notesText == "notes")
        #expect(state.dateEpochDay == 20700)
        #expect(state.minuteOfDay == 630)
        #expect(state.selectedOffsets == [60, 1440])
        navigator.stop()
    }

    /// `AppointmentEditorViewModelTest.kt:144-163`. The three snackbar assertions are the detail
    /// suite's, and are recorded as divergence (b): the iOS undo snackbar auto-dismisses with the
    /// undo window where Android's is indefinite.
    @Test("delete confirms first, then defers the write and closes")
    func deleteConfirmsFirstThenDefersTheWriteAndCloses() async {
        repository.setAppointments(existing())
        let viewModel = viewModel(appointmentId: "a1")
        await waitUntil("the existing appointment to load") { viewModel.state.minuteOfDay != nil }

        viewModel.onEvent(.deleteClicked)
        #expect(viewModel.state.showDeleteConfirm)
        #expect(navigator.commandLog.isEmpty)
        #expect(repository.current().isEmpty == false)

        viewModel.onEvent(.deleteConfirmed)
        #expect(viewModel.state.showDeleteConfirm == false)
        #expect(deletes.controller.pendingIds == ["a1"])
        #expect(deletes.lastRequest?.message == AppointmentsStrings.deleted)
        #expect(deletes.lastRequest?.actionLabel == SalusUIStrings.undo)
        #expect(deletes.lastRequest?.duration == .milliseconds(PendingDeleteController.undoWindowMillis))
        // `AppointmentEditorViewModelTest.kt:157` — the write waits for the undo window.
        #expect(repository.current().isEmpty == false)
        await waitUntil("the editor to pop") { navigator.commandLog == [.pop] }

        await deletes.closeUndoWindow()
        await waitUntil("the deferred write to commit") { repository.current().isEmpty }
        navigator.stop()
    }

    /// `AppointmentEditorViewModelTest.kt:165-186`.
    @Test("add to calendar emits intent data derived from the edited fields")
    func addToCalendarEmitsIntentDataDerivedFromTheEditedFields() async throws {
        repository.setAppointments(existing())
        let viewModel = viewModel(appointmentId: "a1")
        await waitUntil("the existing appointment to load") { viewModel.state.minuteOfDay != nil }

        viewModel.onEvent(.addToCalendarClicked)

        let effect = try #require(viewModel.consumeEffect())
        guard case let .addToCalendar(draft) = effect else { return }
        let expectedBegin = Self.startsAt.instant(in: Self.zone)
        #expect(draft.title == "Dental checkup")
        #expect(draft.location == "Clinic A")
        #expect(draft.notes == "Dr. X\nnotes")
        #expect(draft.start == expectedBegin)
        // The existing appointment's own duration (45 min) defines the end time.
        #expect(draft.end == expectedBegin.addingTimeInterval(45 * 60))
        // The effect is a one-shot: consuming it clears it, so a redraw cannot present twice.
        #expect(viewModel.pendingEffect == nil)
        navigator.stop()
    }
}
