// Ported from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/appointments/
// ui/detail/AppointmentDetailViewModel.kt`.
//
// How the Kotlin flow graph is spelled in Swift:
//
//   `combine(observeAppointment(id), profileRepository.observeProfile(), showDeleteConfirm) { … }`
//   — the two repository arms are `AsyncThrowingStream`s and go through `latestOfBoth`, this
//   package's `combine`-of-two, which already emits nothing until both sides have produced a value
//   and pairs every later emission with the other's latest. The third arm is not a stream at all
//   here: `showDeleteConfirm` is view state the events set directly on `state`, and `republish()`
//   carries it across a repository or profile emission the way `combine`'s lambda reads it.
//
//   `.stateIn(scope, WhileSubscribed(5_000), AppointmentDetailUiState())` — `@Observable` has no
//   subscription-count hook, so the observation runs from `init` to `deinit` instead of starting
//   and stopping with the UI. The initial value is the same `AppointmentDetailUiState()`, and
//   `deinit` cancels the collection through `CancellationBox`. This is `AppointmentsViewModel`'s
//   shape, unchanged.

import Foundation
import Observation
import SalusCommon
import SalusModel
import SalusNavigation
import SalusProfile
import SalusUI

/// Drives one appointment's detail screen (`AppointmentDetailViewModel.kt:20-71`).
@MainActor
@Observable
public final class AppointmentDetailViewModel {
    /// `AppointmentDetailViewModel.kt:31` — what the screen draws.
    public private(set) var state = AppointmentDetailUiState()

    private let appointmentId: String
    private let repository: any AppointmentsRepository
    private let navigator: Navigator
    private let undoableDelete: UndoableDelete
    private let clock: any SalusClock

    /// The latest pair the appointment and profile observations have formed, or nil while
    /// `latestOfBoth` has emitted nothing — the state `combine` is in before all of its sources
    /// have produced a value.
    private var loaded: (appointment: Appointment?, profile: Profile?)?

    /// The collection. Boxed so `deinit` can cancel it — see `CancellationBox`.
    private let observation = CancellationBox()

    public init(
        appointmentId: String,
        repository: any AppointmentsRepository,
        profileRepository: any ProfileRepository,
        navigator: Navigator,
        undoableDelete: UndoableDelete,
        clock: any SalusClock
    ) {
        self.appointmentId = appointmentId
        self.repository = repository
        self.navigator = navigator
        self.undoableDelete = undoableDelete
        self.clock = clock

        let pairs = latestOfBoth(
            repository.observeAppointment(id: appointmentId),
            profileRepository.observeProfile()
        ) { ($0, $1) }
        observation.replace(with: Task { [weak self] in
            do {
                for try await (appointment, profile) in pairs {
                    guard let self else { return }
                    loaded = (appointment, profile)
                    republish()
                }
            } catch {
                // A failing `Flow` cancels its collector on Android and the screen keeps whatever
                // it last drew; the same happens here, and it is this package's house pattern —
                // `AppointmentsViewModel.start()` records the reasoning in full, including the
                // visible edge that a failure before the first pair leaves the screen spinning on
                // both platforms.
            }
        })
    }

    deinit {
        observation.cancel()
    }

    /// `AppointmentDetailViewModel.kt:55-70`.
    public func onEvent(_ event: AppointmentDetailEvent) {
        switch event {
        case .deleteClicked:
            state.showDeleteConfirm = true

        case .deleteDismissed:
            state.showDeleteConfirm = false

        case .deleteConfirmed:
            delete()
        }
    }

    /// `AppointmentDetailViewModel.kt:62-69`.
    private func delete() {
        state.showDeleteConfirm = false
        // The write is held for the undo window by an app-scoped controller, so popping this
        // screen — and with it this ViewModel — does not cancel it.
        undoableDelete(appointmentId, message: AppointmentsStrings.deleted) { [repository, appointmentId] in
            // Swallowed exactly as `WeightEditorViewModel.delete()` swallows it: the commit runs
            // after the screen is gone, so there is nothing left to tell and nobody to act on it.
            try? await repository.deleteAppointment(id: appointmentId)
        }
        navigator.pop()
    }

    /// `combine`'s lambda (`AppointmentDetailViewModel.kt:38-51`).
    ///
    /// The zone is read on every emission, not captured in `init`: a wall-clock start has to be
    /// resolved with the zone that is current *now*, which is the whole reason the bounds are
    /// derived rather than stored.
    private func republish() {
        guard let loaded else { return }
        let appointment = loaded.appointment
        let startEpochMs = appointment?.startsAt.instant(in: clock.timeZone()).epochMilliseconds
        state = AppointmentDetailUiState(
            isLoading: false,
            appointment: appointment,
            healthNotes: nonBlank(loaded.profile?.healthNotes),
            startEpochMs: startEpochMs ?? 0,
            endEpochMs: startEpochMs.map { start in
                start + Int64(appointment?.durationMinutes ?? 0) * Self.millisPerMinute
            } ?? 0,
            showDeleteConfirm: state.showDeleteConfirm
        )
    }

    /// `AppointmentDetailViewModel.kt:73-75`.
    private static let millisPerMinute: Int64 = 60000
}
