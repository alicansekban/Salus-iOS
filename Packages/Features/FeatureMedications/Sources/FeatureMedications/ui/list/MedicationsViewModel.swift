// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/list/MedicationsViewModel.kt`.
//
// How the Kotlin flow graph is spelled in Swift — the same five arms, in the same order:
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
//   `dayRefresh` (`MedicationsViewModel.kt:46`) is the fifth arm and has no stored twin at all: its
//   only job on Android is to make the `combine` re-run, and `republish()` IS that re-run. A
//   `takeDoseClicked` that finds the day has turned calls it directly.
//
//   `.stateIn(scope, WhileSubscribed(5_000), MedicationsUiState())` — `@Observable` has no
//   subscription-count hook, so the observation runs from `init` to `deinit` instead of starting
//   and stopping with the UI. The initial value is the same `MedicationsUiState()`, and `deinit`
//   cancels the collection through `CancellationBox`.
//
// **THE DAY AND THE MINUTE ARE READ PER EMISSION, never once at construction, and that is Android's
// M15 critical fix (`MedicationsViewModel.kt:58-61`, `:67-68`).** A tab root lives for the whole app
// session, so this view model outlives midnight; a day captured in `init` would keep the list
// reporting yesterday, and the dose a card offers would write an intake row dated to it. The queried
// log range is therefore only a *bound* — padded forward by `queryLookaheadDays` so the days the
// root rolls into are still among the rows it observes — while the seven-day share window, the day
// and the minute are all re-derived from the clock inside `republish()`.
//
// **THE NUMBER ON THE CARD IS A DIFFERENT NUMBER FROM ANDROID'S, and that is decision 1.** Kotlin
// calls its own calculator with `(medications, logs, from, to, nowDay, nowMinute)`, which divides
// TAKEN doses by the occurrences `DoseOccurrenceGenerator` expands over the window. This
// calls ``RecordedDoseRatio/perMedication(logs:fromEpochDay:toEpochDay:)``, which divides TAKEN by
// RECORDED — no `MISSED` row is ever written, so a dose nobody logged is an absent record and not a
// failure (`RecordedDoseRatio.swift:1-13`, spec 7 and 12). Two visible consequences: the ratio
// needs neither the medication list nor the current minute, so Kotlin's two extra arguments to it
// have no twin here (the clock is still read per emission — `TodayDoses` needs both); and a
// medication with no logs in the window is absent from the result, which the card draws as "no bar"
// rather than as 0%.

import Foundation
import Observation
import SalusCommon
import SalusUI

/// Drives the medications list (`MedicationsViewModel.kt:23-142`).
@MainActor
@Observable
public final class MedicationsViewModel {
    /// `MedicationsViewModel.kt:48` — what the screen draws.
    public private(set) var state = MedicationsUiState()

    /// `MedicationsViewModel.kt:137` — the window the share is computed over, in days.
    ///
    /// `private`, as Kotlin's `private companion object` is: the two bounds below are the whole
    /// surface, and a caller that needed the constant would be recomputing them.
    private static let recordedDoseWindowDays = 7

    /// `MedicationsViewModel.kt:140-141` — how many days past construction the observed range still
    /// covers a rolled-over day.
    private static let queryLookaheadDays = 7

    private let pendingDeletes: PendingDeleteController
    private let deleteMedication: DeleteMedicationUseCase
    private let markDoseTaken: MarkDoseTakenUseCase
    private let undoableDelete: UndoableDelete
    private let clock: any SalusClock

    /// `MedicationsViewModel.kt:39-41` — the bounds the DAO is asked for, read once when the
    /// observation opens. Not the window anything is computed over; see the file header.
    private let queryStartEpochDay: Int
    private let queryEndEpochDay: Int

    /// `MedicationsViewModel.kt:43` — the id whose confirmation dialog is open, or nil.
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
        markDoseTaken: MarkDoseTakenUseCase,
        undoableDelete: UndoableDelete,
        clock: any SalusClock
    ) {
        self.pendingDeletes = pendingDeletes
        self.deleteMedication = deleteMedication
        self.markDoseTaken = markDoseTaken
        self.undoableDelete = undoableDelete
        self.clock = clock
        // `MedicationsViewModel.kt:39-41` — the DAO bounds only, padded forward so a root that
        // outlives midnight still observes the rows of the day it rolls into. The meaningful window
        // is re-derived per emission in `republish()`.
        let today = clock.todayEpochDay()
        queryStartEpochDay = today - (Self.recordedDoseWindowDays - 1)
        queryEndEpochDay = today + Self.queryLookaheadDays
        start(repository: repository)
    }

    deinit {
        observation.cancel()
    }

    /// `MedicationsViewModel.kt:99-134`.
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

        case let .takeDoseClicked(dose):
            takeDose(dose)
        }
    }

    /// `MedicationsViewModel.kt:115-132` — the notification action's use case, not a write path of
    /// the list's own: the second call for the same dose is a no-op and decrements no stock twice.
    ///
    /// The day is re-read here rather than trusted from the state: the card may have been built
    /// before midnight, and recording it now would date an intake row to yesterday. A dose that no
    /// longer belongs to today is refused, and the state re-derived so the card offers the right
    /// one — which is what Kotlin's `dayRefresh` bump amounts to.
    private func takeDose(_ dose: PendingDose) {
        let today = clock.todayEpochDay()
        guard dose.epochDay == today else {
            republish()
            return
        }
        Task { [markDoseTaken] in
            // Swallowed as everywhere else in this feature: the row re-emits through the repository
            // either way, and there is no retry affordance on either platform.
            try? await markDoseTaken(
                scheduleId: dose.scheduleId,
                epochDay: today,
                minuteOfDay: dose.minuteOfDay
            )
        }
    }

    /// `MedicationsViewModel.kt:105-111`.
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
            repository.observeLogsBetween(fromEpochDay: queryStartEpochDay, toEpochDay: queryEndEpochDay)
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
    /// This is the `pendingIds` arm of the `combine` (`MedicationsViewModel.kt:51`).
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

    /// `combine`'s lambda (`MedicationsViewModel.kt:54-92`).
    ///
    /// Rows vanish the moment a delete is confirmed and come back on undo, without a repository
    /// round trip in either direction.
    private func republish() {
        guard let loaded else { return }
        let pending = pendingDeletes.pendingIds
        // `MedicationsViewModel.kt:57`.
        let medications = loaded.medications.filter { !pending.contains($0.medication.id) }
        // `MedicationsViewModel.kt:61`, `:67-68` — both the day and the minute per emission, so a
        // view model that outlives midnight reports the day it is actually in and a card stops
        // offering a dose the moment the day it belongs to is over.
        let todayEpochDay = clock.todayEpochDay()
        let nowMinuteOfDay = clock.minuteOfDayNow()
        // Kotlin hands the filtered list to its calculator because that calculator expands each
        // medication's schedule; this one reads only logs and is keyed by medication id, so a
        // pending row's entry is simply never looked up. Same result, one fewer argument.
        let ratios = RecordedDoseRatio.perMedication(
            logs: loaded.logs,
            fromEpochDay: todayEpochDay - (Self.recordedDoseWindowDays - 1),
            toEpochDay: todayEpochDay
        )
        // `MedicationsViewModel.kt:69-85`.
        let items = medications.map { item in
            let today = TodayDoses.of(
                medication: item,
                logs: loaded.logs.filter { $0.medicationId == item.medication.id },
                todayEpochDay: todayEpochDay,
                nowMinuteOfDay: nowMinuteOfDay
            )
            return MedicationListItem(
                medication: item.medication,
                schedules: item.schedules,
                // `(it * 100).roundToInt()` (`MedicationsViewModel.kt:79-80`). The ratio is rounded
                // exactly once, here, so the card and anything else that reads the state see the
                // same whole percent.
                recordedDosePercent: ratios[item.medication.id].map { Int(($0 * 100).rounded()) },
                dayStatus: today.status,
                nextDoseMinuteOfDay: today.nextDoseMinuteOfDay,
                dueDose: today.dueDose
            )
        }
        state = MedicationsUiState(
            isLoading: false,
            medications: items,
            // `medications.firstOrNull { it.medication.id == confirmingId }?.medication`
            // (`MedicationsViewModel.kt:89`): a row that has already left the list — deleted
            // elsewhere while its dialog was open — closes the dialog rather than asking about
            // something that is no longer there.
            pendingDelete: medications.first { $0.medication.id == pendingDeleteId }?.medication,
            // `items.mapNotNull { it.nextDoseMinuteOfDay }.minOrNull()`
            // (`MedicationsViewModel.kt:90`).
            nextDoseMinuteOfDay: items.compactMap(\.nextDoseMinuteOfDay).min(),
            todayEpochDay: todayEpochDay
        )
    }
}
