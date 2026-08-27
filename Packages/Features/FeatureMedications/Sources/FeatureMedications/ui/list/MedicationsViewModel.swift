// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/list/MedicationsViewModel.kt`.
//
// How the Kotlin flow graph is spelled in Swift — the same four arms, in the same order:
//
//   `combine(observeActiveMedications(), observeLogsBetween(from, to), …)` — the two repository
//   arms are `AsyncThrowingStream`s and go through `latestOfBoth`, this package's `combine`-of-two,
//   which emits nothing until both sides have produced a value and pairs every later emission with
//   the other's latest.
//
//   `pendingDeletes.pendingIds` is an `@Observable` property, so it is read inside
//   `withObservationTracking`, whose `onChange` fires **once** and must therefore re-register
//   itself. `onChange` also runs *before* the new value is stored, which is why the re-registration
//   hops through a `Task { @MainActor }` and why a test reads the list through `waitUntil` rather
//   than straight after a delete. This is `AppointmentsViewModel.trackPendingDeletes`, unchanged.
//
//   `pendingDeleteId` is a `MutableStateFlow` on Android and plain state here (divergence (f)):
//   nothing outside this class observes it, so the fourth arm of the `combine` becomes a stored
//   property plus a `republish()`.
//
//   `.stateIn(scope, WhileSubscribed(5_000), MedicationsUiState())` — `@Observable` has no
//   subscription-count hook, so the observation runs from `init` to `deinit` instead of starting
//   and stopping with the UI. The initial value is the same `MedicationsUiState()`, and `deinit`
//   cancels the collection through `CancellationBox`.
//
// **THE NUMBER ON THE CARD IS A DIFFERENT NUMBER FROM ANDROID'S, and that is decision 1.** Kotlin
// calls its own calculator with `(medications, logs, from, to, nowDay, nowMinute)`, which divides
// TAKEN doses by the occurrences `DoseOccurrenceGenerator` expands over the window. This
// calls ``RecordedDoseRatio/perMedication(logs:fromEpochDay:toEpochDay:)``, which divides TAKEN by
// RECORDED — no `MISSED` row is ever written, so a dose nobody logged is an absent record and not a
// failure (`RecordedDoseRatio.swift:1-13`, spec 7 and 12). Two visible consequences: the ratio
// needs neither the medication list nor the current minute, so `nowEpochDay`/`nowMinuteOfDay` have
// no twin here; and a medication with no logs in the window is absent from the result, which the
// card draws as "no bar" rather than as 0%.

import Foundation
import Observation
import SalusCommon
import SalusUI

/// Drives the medications list (`MedicationsViewModel.kt:20-89`).
@MainActor
@Observable
public final class MedicationsViewModel {
    /// `MedicationsViewModel.kt:33` — what the screen draws.
    public private(set) var state = MedicationsUiState()

    /// `MedicationsViewModel.kt:87` — the window the share is computed over, in days.
    ///
    /// `private`, as Kotlin's `private companion object` is: the two bounds below are the whole
    /// surface, and a caller that needed the constant would be recomputing them.
    private static let recordedDoseWindowDays = 7

    private let pendingDeletes: PendingDeleteController
    private let deleteMedication: DeleteMedicationUseCase
    private let undoableDelete: UndoableDelete

    /// `MedicationsViewModel.kt:28-29` — `[today - 6, today]`, inclusive at both ends. Read once,
    /// when the observation opens, so the window the logs are queried over and the window the ratio
    /// is computed over cannot drift apart across midnight.
    private let windowStartEpochDay: Int
    private let windowEndEpochDay: Int

    /// `MedicationsViewModel.kt:31` — the id whose confirmation dialog is open, or nil.
    private var pendingDeleteId: String?

    /// The latest pair the two streams have formed, or nil while `latestOfBoth` has emitted nothing
    /// — the state `combine` is in before all of its sources have produced a value. A `pendingIds`
    /// change arriving before that first pair must not paint an empty list over the initial loading
    /// state, which is what `republish()`'s `guard` is for.
    private var loaded: (medications: [MedicationWithSchedules], logs: [IntakeLog])?

    /// The collection. Boxed so `deinit` can cancel it — see `CancellationBox`.
    private let observation = CancellationBox()

    public init(
        repository: any MedicationRepository,
        pendingDeletes: PendingDeleteController,
        deleteMedication: DeleteMedicationUseCase,
        undoableDelete: UndoableDelete,
        clock: any SalusClock
    ) {
        self.pendingDeletes = pendingDeletes
        self.deleteMedication = deleteMedication
        self.undoableDelete = undoableDelete
        let today = clock.todayEpochDay()
        windowStartEpochDay = today - (Self.recordedDoseWindowDays - 1)
        windowEndEpochDay = today
        start(repository: repository)
    }

    deinit {
        observation.cancel()
    }

    /// `MedicationsViewModel.kt:70-84`.
    public func onEvent(_ event: MedicationsEvent) {
        switch event {
        case let .deleteRequested(id):
            pendingDeleteId = id
            republish()

        case .deleteDismissed:
            pendingDeleteId = nil
            republish()

        case .deleteConfirmed:
            confirmDelete()
        }
    }

    /// `MedicationsViewModel.kt:76-82`.
    ///
    /// Same hold-for-undo path as the detail screen; the list filters the id out through
    /// `pendingIds` until the window closes or the user undoes. Nothing else happens — the list
    /// does not navigate, because the row that was deleted is the only thing that leaves.
    private func confirmDelete() {
        guard let id = pendingDeleteId else { return }
        pendingDeleteId = nil
        republish()
        undoableDelete(id, message: MedicationsStrings.deleted) { [deleteMedication] in
            // Swallowed as everywhere else in this feature: the commit runs after the undo window
            // closes, by which time there is nobody left to tell.
            try? await deleteMedication(id: id)
        }
    }

    private func start(repository: any MedicationRepository) {
        trackPendingDeletes()
        let pairs = latestOfBoth(
            repository.observeActiveMedications(),
            repository.observeLogsBetween(fromEpochDay: windowStartEpochDay, toEpochDay: windowEndEpochDay)
        ) { ($0, $1) }
        observation.replace(with: Task { [weak self] in
            do {
                for try await (medications, logs) in pairs {
                    guard let self else { return }
                    loaded = (medications, logs)
                    republish()
                }
            } catch {
                // A failing `Flow` cancels its collector on Android and the screen keeps whatever it
                // last drew; the same happens here, and it is this port's house pattern — there is
                // no retry affordance on either platform, so there is nothing the user could act
                // on. Its one visible edge, said plainly: a failure *before* the first pair leaves
                // `loaded` nil, so `state.isLoading` stays true and the screen spins rather than
                // showing an error. Android's spinner is equally permanent (`stateIn`'s initial
                // value is the loading state and the cancelled flow never replaces it), so this is
                // the ported behaviour and not a dropped case.
            }
        })
    }

    /// Re-registers itself after every change, because `withObservationTracking` fires once.
    ///
    /// This is the `pendingIds` arm of the `combine` (`MedicationsViewModel.kt:36`).
    private func trackPendingDeletes() {
        withObservationTracking {
            _ = pendingDeletes.pendingIds
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.republish()
                self.trackPendingDeletes()
            }
        }
    }

    /// `combine`'s lambda (`MedicationsViewModel.kt:40-63`).
    ///
    /// Rows vanish the moment a delete is confirmed and come back on undo, without a repository
    /// round trip in either direction.
    private func republish() {
        guard let loaded else { return }
        let pending = pendingDeletes.pendingIds
        // `MedicationsViewModel.kt:43`.
        let medications = loaded.medications.filter { !pending.contains($0.medication.id) }
        // Kotlin hands the filtered list to its calculator because that calculator expands each
        // medication's schedule; this one reads only logs and is keyed by medication id, so a
        // pending row's entry is simply never looked up. Same result, one fewer argument.
        let ratios = RecordedDoseRatio.perMedication(
            logs: loaded.logs,
            fromEpochDay: windowStartEpochDay,
            toEpochDay: windowEndEpochDay
        )
        state = MedicationsUiState(
            isLoading: false,
            medications: medications.map { item in
                MedicationListItem(
                    medication: item.medication,
                    schedules: item.schedules,
                    // `(it * 100).roundToInt()` (`MedicationsViewModel.kt:58-59`). The ratio is
                    // rounded exactly once, here, so the card and anything else that reads the
                    // state see the same whole percent.
                    recordedDosePercent: ratios[item.medication.id].map { Int(($0 * 100).rounded()) }
                )
            },
            // `medications.firstOrNull { it.medication.id == confirmingId }?.medication`
            // (`MedicationsViewModel.kt:62`): a row that has already left the list — deleted
            // elsewhere while its dialog was open — closes the dialog rather than asking about
            // something that is no longer there.
            pendingDelete: medications.first { $0.medication.id == pendingDeleteId }?.medication
        )
    }
}
