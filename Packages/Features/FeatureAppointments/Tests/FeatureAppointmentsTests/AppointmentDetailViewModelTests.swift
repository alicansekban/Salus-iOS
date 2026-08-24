// Ported from `feature/appointments/src/test/kotlin/com/alicansekban/salus/feature/appointments/
// ui/detail/AppointmentDetailViewModelTest.kt` — all seven cases, by name, in the Kotlin order.
//
// The mechanical differences are the ones this target already settled:
// Turbine's `state.test { skipItems(1); awaitItem() }` becomes reading `viewModel.state` after
// `waitUntil`, because the iOS state is an `@Observable` property rather than a `StateFlow`;
// `MainDispatcherRule` has no twin — `@MainActor` on the suite is the whole mechanism; and
// `advanceUntilIdle()` closing the undo window becomes `TestDeletes.closeUndoWindow()`, the gate
// `PendingDeleteController`'s injected `sleep` waits on.
//
// One assertion diverges, and it is recorded in the global constraints as divergence (b): Kotlin
// asserts only that one snackbar was shown, because Android's undo snackbar is indefinite. The iOS
// one auto-dismisses with the undo window, so the request's action label and duration are asserted
// here — that is the behaviour the divergence introduced, and nothing else pins it.

import Foundation
import SalusCommon
import SalusModel
import SalusNavigation
import SalusTesting
import SalusUI
import Testing

@testable import FeatureAppointments

@Suite("AppointmentDetailViewModel")
@MainActor
struct AppointmentDetailViewModelTests {
    /// `AppointmentDetailViewModelTest.kt:42-44` — the same zone, start and "now".
    private static let zone = FixedSalusClock.defaultZone
    private static let startsAt = LocalDateTime(
        date: LocalDate(year: 2026, month: 8, day: 18),
        minuteOfDay: 10 * 60
    )

    private let clock = FixedSalusClock(
        now: LocalDateTime(date: LocalDate(year: 2026, month: 8, day: 1), minuteOfDay: 9 * 60)
            .instant(in: AppointmentDetailViewModelTests.zone),
        timeZone: AppointmentDetailViewModelTests.zone
    )
    private let repository = FakeAppointmentsRepository(zone: AppointmentDetailViewModelTests.zone)
    private let profiles = FakeProfileRepository()
    private let navigator = FakeNavigator()
    private let deletes = TestDeletes()

    /// `AppointmentDetailViewModelTest.kt:50-57`.
    private func viewModel() -> AppointmentDetailViewModel {
        AppointmentDetailViewModel(
            appointmentId: "a1",
            repository: repository,
            profileRepository: profiles,
            navigator: navigator.navigator,
            undoableDelete: deletes.undoableDelete,
            clock: clock
        )
    }

    /// `AppointmentDetailViewModelTest.kt:59-71`.
    private func appointment() -> Appointment {
        Appointment(
            id: "a1",
            title: "Annual check-up",
            doctorName: "Dr. Lee",
            specialty: "Cardiology",
            location: "City Clinic",
            notes: "Bring blood test results",
            startsAt: Self.startsAt,
            timeZone: Self.zone,
            durationMinutes: 30,
            status: .scheduled,
            reminderOffsetsMinutes: [1440]
        )
    }

    /// `AppointmentDetailViewModelTest.kt:73-87`.
    @Test("state carries the appointment and the profile's health notes")
    func stateCarriesTheAppointmentAndTheProfilesHealthNotes() async {
        repository.setAppointments(appointment())
        profiles.setProfile(testProfile(healthNotes: "Pollen allergy"))
        let viewModel = viewModel()

        await waitUntil("the first emission") { !viewModel.state.isLoading }
        let loaded = viewModel.state

        #expect(loaded.isLoading == false)
        #expect(loaded.appointment?.title == "Annual check-up")
        #expect(loaded.healthNotes == "Pollen allergy")
        navigator.stop()
    }

    /// `AppointmentDetailViewModelTest.kt:89-98`.
    @Test("blank health notes are treated as absent")
    func blankHealthNotesAreTreatedAsAbsent() async {
        repository.setAppointments(appointment())
        profiles.setProfile(testProfile(healthNotes: "   "))
        let viewModel = viewModel()

        await waitUntil("the first emission") { !viewModel.state.isLoading }

        #expect(viewModel.state.healthNotes == nil)
        navigator.stop()
    }

    /// `AppointmentDetailViewModelTest.kt:100-113`.
    @Test("calendar bounds come from the wall-clock start and the duration")
    func calendarBoundsComeFromTheWallClockStartAndTheDuration() async {
        repository.setAppointments(appointment())
        let viewModel = viewModel()

        await waitUntil("the first emission") { !viewModel.state.isLoading }
        let loaded = viewModel.state

        let expectedStart = Self.startsAt.instant(in: Self.zone).epochMilliseconds
        #expect(loaded.startEpochMs == expectedStart)
        #expect(loaded.endEpochMs == expectedStart + 30 * 60000)
        navigator.stop()
    }

    /// `AppointmentDetailViewModelTest.kt:115-128`.
    @Test("delete asks before it does anything")
    func deleteAsksBeforeItDoesAnything() async {
        repository.setAppointments(appointment())
        let viewModel = viewModel()
        await waitUntil("the first emission") { !viewModel.state.isLoading }

        viewModel.onEvent(.deleteClicked)

        #expect(viewModel.state.showDeleteConfirm)
        #expect(repository.current().isEmpty == false)
        #expect(navigator.commandLog.isEmpty)
        navigator.stop()
    }

    /// `AppointmentDetailViewModelTest.kt:130-145`. The last two assertions are divergence (b).
    @Test("confirming defers the write, closes the screen and offers undo")
    func confirmingDefersTheWriteClosesTheScreenAndOffersUndo() async {
        repository.setAppointments(appointment())
        let viewModel = viewModel()

        viewModel.onEvent(.deleteConfirmed)

        #expect(deletes.controller.pendingIds == ["a1"])
        #expect(repository.current().isEmpty == false)
        #expect(deletes.lastRequest?.message == AppointmentsStrings.deleted)
        #expect(deletes.lastRequest?.actionLabel == SalusUIStrings.undo)
        #expect(deletes.lastRequest?.duration == .milliseconds(PendingDeleteController.undoWindowMillis))
        await waitUntil("the screen to pop") { navigator.commandLog == [.pop] }

        // `AppointmentDetailViewModelTest.kt:137` — `assertEquals(1, deletes.snackbar.shown.size)`.
        // The iOS controller publishes the snackbar on screen rather than a log of every request
        // (`TestDeletes.swift` records why it is the real controller and not a recorder), so
        // "exactly one" is spelled as: one is up, and taking it away brings nothing up behind it.
        deletes.snackbar.dismiss()
        #expect(deletes.lastRequest == nil)

        await deletes.closeUndoWindow()
        await waitUntil("the deferred write to commit") { repository.current().isEmpty }
        navigator.stop()
    }

    /// `AppointmentDetailViewModelTest.kt:147-158`.
    @Test("undo cancels the deletion the popped screen started")
    func undoCancelsTheDeletionThePoppedScreenStarted() async {
        repository.setAppointments(appointment())
        let viewModel = viewModel()

        viewModel.onEvent(.deleteConfirmed)
        deletes.undoLast()
        await waitUntil("the undo to clear the pending set") { deletes.controller.pendingIds.isEmpty }

        await deletes.closeUndoWindow()
        #expect(repository.current().isEmpty == false)
        navigator.stop()
    }

    /// `AppointmentDetailViewModelTest.kt:160-170`.
    @Test("an appointment that no longer exists leaves nothing to show")
    func anAppointmentThatNoLongerExistsLeavesNothingToShow() async {
        let viewModel = viewModel()

        await waitUntil("the first emission") { !viewModel.state.isLoading }
        let loaded = viewModel.state

        #expect(loaded.isLoading == false)
        #expect(loaded.appointment == nil)
        #expect(loaded.startEpochMs == 0)
        navigator.stop()
    }
}
