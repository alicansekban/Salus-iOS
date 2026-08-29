// Ported from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/
// ui/calendar/CycleViewModel.kt`.
//
// How the Kotlin flow graph is spelled in Swift — the same four arms of the `combine`
// (`CycleViewModel.kt:46-51`), in the same order:
//
//   `monthFirstDay` is a `MutableStateFlow` on Android and plain state here, and so is
//   `activeReminderDialog` (the divergence `MedicationsViewModel` records for its
//   `pendingDeleteId`): nothing outside this class observes either, so the first and fourth arms
//   become stored properties plus a `republish()` that rebuilds the state synchronously from the
//   last pair the two real streams formed.
//
//   `repository.observePeriods()` is an `AsyncThrowingStream` and `reminderSettings.config` a
//   non-throwing `AsyncStream` (`CycleReminderSettings.swift`, divergence 1). `SalusCommon`'s
//   `latestOfBoth` is `combine`-of-two over two *throwing* streams, so the config side is wrapped
//   rather than a second combinator written for the one shape that differs — the wrapper is
//   ``throwingStream(over:)`` below and it adds no behaviour, only the error type.
//
//   `.stateIn(scope, WhileSubscribed(5_000), CycleUiState())` — `@Observable` has no
//   subscription-count hook, so the observation runs from `init` to `deinit` instead of starting
//   and stopping with the UI. The initial value is the same `CycleUiState()`, and `deinit` cancels
//   the collection through `CancellationBox`.
//
// **The two use-case results are discarded, and that is parity rather than an oversight.** Kotlin
// calls `startPeriod(...)` and `endPeriod(...)` for their effect and ignores what they answer
// (`CycleViewModel.kt:67-76`), so a rejected start — the second tap on a day that already has an
// open period — is silent on both platforms. iOS-M6 files it as an Android follow-up rather than
// diverging here.

import Foundation
import Observation
import SalusCommon
import SalusModel
import SalusReminder

/// Drives the cycle calendar (`CycleViewModel.kt:32-217`).
@MainActor
@Observable
public final class CycleViewModel {
    /// `CycleViewModel.kt:45` — what the screen draws.
    public private(set) var state = CycleUiState()

    private let predictor: CyclePredictor
    private let startPeriod: StartPeriodUseCase
    private let endPeriod: EndPeriodUseCase
    private let clock: any SalusClock
    private let reminderSettings: any CycleReminderSettings
    private let reminderScheduler: any ReminderScheduler

    /// `CycleViewModel.kt:42` — the month the grid is drawn for, paged by the two chevrons.
    private var monthFirstDay: LocalDate

    /// `CycleViewModel.kt:43`.
    private var activeReminderDialog: CycleReminderDialog?

    /// The latest pair the two streams have formed, or nil while `latestOfBoth` has emitted
    /// nothing — the state `combine` is in before all of its sources have produced a value. A month
    /// change arriving before that first pair must not paint an empty grid over the initial loading
    /// state, which is what `republish()`'s `guard` is for.
    private var loaded: (periods: [CyclePeriod], config: CycleReminderConfig)?

    /// The collection. Boxed so `deinit` can cancel it — see `CancellationBox`.
    private let observation = CancellationBox()

    /// Seven parameters, which are the seven Koin resolves for `viewModelOf(::CycleViewModel)`
    /// (`CycleModule.kt:47`). Bundling them into a "dependencies" struct would be a second shape
    /// for the module's own properties, so the Kotlin constructor is kept as it stands.
    public init(
        repository: any CycleRepository,
        predictor: CyclePredictor,
        startPeriod: StartPeriodUseCase,
        endPeriod: EndPeriodUseCase,
        clock: any SalusClock,
        reminderSettings: any CycleReminderSettings,
        reminderScheduler: any ReminderScheduler
    ) {
        self.predictor = predictor
        self.startPeriod = startPeriod
        self.endPeriod = endPeriod
        self.clock = clock
        self.reminderSettings = reminderSettings
        self.reminderScheduler = reminderScheduler
        // `CycleViewModel.kt:42` — the grid opens on the month that holds today.
        monthFirstDay = clock.today().firstDayOfMonth
        start(repository: repository)
    }

    deinit {
        observation.cancel()
    }

    /// `CycleViewModel.kt:59-99`.
    public func onEvent(_ event: CycleEvent) {
        switch event {
        case .previousMonthClicked:
            monthFirstDay = monthFirstDay.minusMonths(1)
            republish()

        case .nextMonthClicked:
            monthFirstDay = monthFirstDay.plusMonths(1)
            republish()

        case .startPeriodClicked:
            startPeriodToday()

        case .endPeriodClicked:
            endPeriodToday()

        case let .reminderToggled(enabled):
            reminderSettings.setEnabled(enabled)
            reminderScheduler.requestSync()

        case let .reminderDialogRequested(dialog):
            activeReminderDialog = dialog
            republish()

        case .reminderDialogDismissed:
            activeReminderDialog = nil
            republish()

        case let .reminderLeadDaysSelected(days):
            reminderSettings.setLeadDays(days)
            closeDialogAndSync()

        case let .reminderTimeSelected(minuteOfDay):
            reminderSettings.setMinuteOfDay(minuteOfDay)
            closeDialogAndSync()
        }
    }

    /// `CycleViewModel.kt:67-71`. The result is discarded — see the file header.
    private func startPeriodToday() {
        Task { [startPeriod, clock, reminderScheduler] in
            // A throw skips the sync, exactly as a failing `suspend` call ends the coroutine
            // Kotlin launches before it reaches `requestSync()`.
            _ = try await startPeriod(startDate: clock.today(), createdAt: clock.now())
            // Period edits move the prediction, so the reminder window must re-sync.
            reminderScheduler.requestSync()
        }
    }

    /// `CycleViewModel.kt:73-76`.
    private func endPeriodToday() {
        Task { [endPeriod, clock, reminderScheduler] in
            _ = try await endPeriod(endDate: clock.today())
            reminderScheduler.requestSync()
        }
    }

    /// The tail the two option pickers share (`CycleViewModel.kt:89-90`, `:95-96`): the popup
    /// closes and the window re-syncs, in that order.
    private func closeDialogAndSync() {
        activeReminderDialog = nil
        republish()
        reminderScheduler.requestSync()
    }

    private func start(repository: any CycleRepository) {
        // Read once: `config` builds a fresh stream per access, so a second read would open a
        // second observation of the same settings.
        let pairs = latestOfBoth(
            repository.observePeriods(),
            Self.throwingStream(over: reminderSettings.config)
        ) { ($0, $1) }
        observation.replace(with: Task { [weak self] in
            do {
                for try await (periods, config) in pairs {
                    guard let self else { return }
                    loaded = (periods, config)
                    republish()
                }
            } catch {
                // A failing `Flow` cancels its collector on Android and the screen keeps whatever
                // it last drew; the same happens here, and it is this port's house pattern — there
                // is no retry affordance on either platform, so there is nothing the user could act
                // on. Its one visible edge, said plainly: a failure *before* the first pair leaves
                // `loaded` nil, so `state.isLoading` stays true and the screen spins rather than
                // showing an error. Android's spinner is equally permanent (`stateIn`'s initial
                // value is the loading state and the cancelled flow never replaces it), so this is
                // the ported behaviour and not a dropped case.
            }
        })
    }

    /// `combine`'s lambda (`CycleViewModel.kt:51-52`), minus the two arms that are local state
    /// here: the month and the open dialog are read straight off the properties, so paging the grid
    /// redraws it without a repository round trip.
    private func republish() {
        guard let loaded else { return }
        state = CycleCalendarBuilder.buildState(
            monthStart: monthFirstDay,
            periods: loaded.periods,
            reminderConfig: loaded.config,
            reminderDialog: activeReminderDialog,
            predictor: predictor,
            // Read per rebuild, exactly where Kotlin reads it (`CycleViewModel.kt:107`).
            today: clock.today()
        )
    }

    /// Re-types a non-throwing `AsyncStream` as the throwing one `latestOfBoth` combines.
    ///
    /// Nothing else changes: every value is forwarded, the end of the source finishes the wrapper,
    /// and a consumer that stops reading cancels the source. `.bufferingNewest(1)` restates the
    /// conflation the settings stream already applies, because `AsyncThrowingStream` is a concrete
    /// type and wrapping means rebuilding.
    private static func throwingStream<Value: Sendable>(
        over source: AsyncStream<Value>
    ) -> AsyncThrowingStream<Value, any Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                for await value in source {
                    continuation.yield(value)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
