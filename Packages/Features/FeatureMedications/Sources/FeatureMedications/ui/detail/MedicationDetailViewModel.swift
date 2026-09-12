// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/detail/MedicationDetailViewModel.kt`.
//
// How the Kotlin flow graph is spelled in Swift — the same three arms, in the same order:
//
//   `combine(observeMedication(id), observeLogsBetween(today - 30, today), showDeleteConfirm) { … }`
//   — the two repository arms are `AsyncThrowingStream`s and go through `latestOfBoth`, this
//   package's `combine`-of-two, which emits nothing until both sides have produced a value and
//   pairs every later emission with the other's latest. The third arm is not a stream here:
//   `showDeleteConfirm` is a `MutableStateFlow` nothing outside the class observes, so it becomes a
//   stored property plus a `republish()` — the same divergence `MedicationsViewModel` records for
//   its `pendingDeleteId` and `AppointmentDetailViewModel` for its own confirmation flag.
//
//   `dayRefresh` (`MedicationDetailViewModel.kt:46`) is the fourth arm and has no stored twin at
//   all: its only job on Android is to make the `combine` re-run, and `republish()` IS that re-run.
//   A `takeDoseClicked` that finds the day has turned calls it directly.
//
//   `.stateIn(scope, WhileSubscribed(5_000), MedicationDetailUiState())` — `@Observable` has no
//   subscription-count hook, so the observation runs from `init` to `deinit` instead of starting
//   and stopping with the UI. The initial value is the same `MedicationDetailUiState()`, and
//   `deinit` cancels the collection through `CancellationBox`.
//
// **THE DAY AND THE MINUTE ARE READ PER EMISSION, never once at construction, and that is Android's
// M15 critical fix (`MedicationDetailViewModel.kt:54-56`, `:61`).** This screen can sit open across
// midnight; a day captured in `init` would keep the rhythm row counting back from yesterday, and
// the dose the "record now" button offers would write an intake row dated to it. The queried log
// range is therefore only a *bound* — padded forward by `queryLookaheadDays` — while the history
// window and the day itself are re-derived from the clock inside `republish()`.

import Foundation
import Observation
import SalusCommon
import SalusModel
import SalusNavigation
import SalusReminder
import SalusUI

/// Drives one medication's detail screen (`MedicationDetailViewModel.kt:23-148`).
@MainActor
@Observable
public final class MedicationDetailViewModel {
    /// `MedicationDetailViewModel.kt:48` — what the screen draws.
    public private(set) var state = MedicationDetailUiState()

    private let medicationId: String
    private let repository: any MedicationRepository
    private let deleteMedication: DeleteMedicationUseCase
    private let markDoseTaken: MarkDoseTakenUseCase
    private let navigator: Navigator
    private let undoableDelete: UndoableDelete
    private let reminderScheduler: any ReminderScheduler
    private let clock: any SalusClock

    /// `MedicationDetailViewModel.kt:143-147` — how many days past construction the observed range
    /// still covers a rolled-over day.
    private static let queryLookaheadDays = 7

    /// `MedicationDetailViewModel.kt:43` — the confirmation flag, off the state until it is
    /// republished with it.
    private var showDeleteConfirm = false

    /// The latest pair the medication and log observations have formed, or nil while
    /// `latestOfBoth` has emitted nothing — the state `combine` is in before all of its sources
    /// have produced a value.
    private var loaded: (medication: MedicationWithSchedules?, logs: [IntakeLog])?

    /// The collection. Boxed so `deinit` can cancel it — see `CancellationBox`.
    private let observation = CancellationBox()

    // The eight parameters are the eight Koin resolves for `MedicationDetailViewModel`
    // (`MedicationsModule.kt:39-49`), in Kotlin's order. No opt-out comment is needed and none is
    // written: `function_parameter_count` exempts initialisers, which is why
    // `makeMedicationsModule` — a free function — has to waive the rule and this does not.
    public init(
        medicationId: String,
        repository: any MedicationRepository,
        deleteMedication: DeleteMedicationUseCase,
        markDoseTaken: MarkDoseTakenUseCase,
        navigator: Navigator,
        undoableDelete: UndoableDelete,
        reminderScheduler: any ReminderScheduler,
        clock: any SalusClock
    ) {
        self.medicationId = medicationId
        self.repository = repository
        self.deleteMedication = deleteMedication
        self.markDoseTaken = markDoseTaken
        self.navigator = navigator
        self.undoableDelete = undoableDelete
        self.reminderScheduler = reminderScheduler
        self.clock = clock

        // `MedicationDetailViewModel.kt:40-41` — the DAO bounds only, padded forward so a screen
        // that outlives midnight still observes the rows of the day it rolls into. The history
        // window and the day itself are re-derived per emission in `republish()`.
        let today = clock.todayEpochDay()
        let pairs = latestOfBoth(
            repository.observeMedication(id: medicationId),
            repository.observeLogsBetween(
                fromEpochDay: today - historyWindowDays,
                toEpochDay: today + Self.queryLookaheadDays
            )
        ) { ($0, $1) }
        observation.replace(with: Task { [weak self] in
            do {
                for try await (medication, logs) in pairs {
                    guard let self else { return }
                    loaded = (medication, logs)
                    republish()
                }
            } catch {
                // A failing `Flow` cancels its collector on Android and the screen keeps whatever
                // it last drew; the same happens here, and it is this package's house pattern —
                // `MedicationsViewModel.start()` records the reasoning in full, including the
                // visible edge that a failure before the first pair leaves the screen spinning on
                // both platforms.
            }
        })
    }

    deinit {
        observation.cancel()
    }

    /// `MedicationDetailViewModel.kt:99-141`.
    public func onEvent(_ event: MedicationDetailEvent) {
        switch event {
        case .deleteClicked:
            showDeleteConfirm = true
            republish()

        case .deleteDismissed:
            showDeleteConfirm = false
            republish()

        case .deleteConfirmed:
            confirmDelete()

        case let .remindersToggled(enabled):
            setRemindersEnabled(enabled)

        case let .takeDoseClicked(dose):
            takeDose(dose)
        }
    }

    /// `MedicationDetailViewModel.kt:122-139` — the notification action's use case, not a second
    /// write path of this screen's own.
    ///
    /// The day is re-read here rather than trusted from the state: the screen may have been built
    /// before midnight, and recording it now would date an intake row to yesterday. A dose that no
    /// longer belongs to today is refused, and the state re-derived so the screen offers the right
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

    /// `MedicationDetailViewModel.kt:105-113`.
    private func confirmDelete() {
        showDeleteConfirm = false
        republish()
        // The write is held for the undo window by an app-scoped controller, so popping this
        // screen — and with it this ViewModel — does not cancel it.
        undoableDelete(medicationId, message: MedicationsStrings.deleted) { [deleteMedication, medicationId] in
            // Swallowed as everywhere else in this feature: the commit runs after the screen is
            // gone, so there is nothing left to tell and nobody to act on it.
            try? await deleteMedication(id: medicationId)
        }
        navigator.pop()
    }

    /// `MedicationDetailViewModel.kt:117-120`.
    ///
    /// The sync drops the pending alarms on the next window pass, exactly as a delete does; the
    /// handler already skips silenced medications.
    ///
    /// The write is unstructured where Kotlin's is a `viewModelScope.launch`, so it outlives a pop
    /// rather than being cancelled with the screen. Nothing observable turns on the difference —
    /// the toggle draws `medication.remindersEnabled` as the repository re-emits it either way —
    /// and letting a one-row update finish is the safer half of the choice.
    private func setRemindersEnabled(_ enabled: Bool) {
        Task { [repository, reminderScheduler, medicationId] in
            do {
                try await repository.setRemindersEnabled(medicationId: medicationId, enabled: enabled)
                reminderScheduler.requestSync()
            } catch {
                // Kotlin's `launch` would let the write's failure reach the coroutine handler and
                // never reach `requestSync()`; the `do`/`catch` keeps that order. There is no
                // failure affordance on either platform — the switch simply snaps back when the
                // repository re-emits the unchanged row.
            }
        }
    }

    /// `combine`'s lambda (`MedicationDetailViewModel.kt:53-92`).
    private func republish() {
        guard let loaded else { return }
        // `MedicationDetailViewModel.kt:56`, `:61` — both the day and the minute per emission, so a
        // screen that outlives midnight reports the day it is actually in.
        let todayEpochDay = clock.todayEpochDay()
        // `MedicationDetailViewModel.kt:57-60` — the history window is re-derived from that day
        // rather than from the padded query bounds, so a row from tomorrow that the lookahead pulled
        // in is not drawn today.
        let ownLogs = loaded.logs.filter {
            $0.medicationId == medicationId
                && ((todayEpochDay - historyWindowDays) ... todayEpochDay).contains($0.epochDay)
        }
        let todayDoses = loaded.medication.map {
            TodayDoses.of(
                medication: $0,
                logs: ownLogs,
                todayEpochDay: todayEpochDay,
                nowMinuteOfDay: clock.minuteOfDayNow()
            )
        }
        state = MedicationDetailUiState(
            isLoading: false,
            medication: loaded.medication?.medication,
            schedules: loaded.medication?.schedules ?? [],
            history: ownLogs
                // `compareByDescending { epochDay }.thenByDescending { minuteOfDay }`
                // (`MedicationDetailViewModel.kt:75`).
                .sorted { left, right in
                    left.epochDay == right.epochDay
                        ? left.minuteOfDay > right.minuteOfDay
                        : left.epochDay > right.epochDay
                }
                .map {
                    IntakeHistoryItem(
                        epochDay: $0.epochDay,
                        minuteOfDay: $0.minuteOfDay,
                        status: $0.status,
                        doseAmount: $0.doseAmount
                    )
                },
            showDeleteConfirm: showDeleteConfirm,
            // `MedicationDetailViewModel.kt:86-89`.
            daysOfSupply: TodayDoses.daysOfSupply(
                stockCount: loaded.medication?.medication.stockCount,
                schedules: loaded.medication?.schedules ?? []
            ),
            pendingDose: todayDoses?.dueDose,
            todayEpochDay: todayEpochDay
        )
    }
}
