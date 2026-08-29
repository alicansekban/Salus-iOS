// Ported 1:1 from `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/ui/
// HomeViewModel.kt`.
//
// How the Kotlin flow graph is spelled in Swift, piece by piece:
//
//   `combine(repository.observeTodayOverview(), aiSummaryRepository.freeSummaryAvailable,
//   premiumRepository.status) { … }` — `SalusCommon`'s ``latestOfThree``, whose semantics are
//   `combine`'s (nothing until every source has produced a value, then any source's value emits
//   carrying the others' latest). The two flag sources are non-throwing `AsyncStream`s, so each goes
//   through ``throwingStream(over:)`` to be re-typed; the combinator takes no transform, so the
//   Kotlin lambda becomes ``publish(overview:freeAiSummaryAvailable:isPremium:)`` at the end of the
//   loop instead of inside the operator.
//
//   `.stateIn(scope, WhileSubscribed(5_000), HomeUiState())` — `@Observable` has no
//   subscription-count hook, so the collection runs from `init` to `deinit`, starting from the same
//   `HomeUiState()`, and `deinit` cancels it through `CancellationBox`. The half of
//   `WhileSubscribed` that is **behavioural here** — `TodayRepositoryImpl.observeTodayOverview()`
//   captures `today` / `nowMinute` / `nowMs` eagerly, so re-collecting is what re-captures them —
//   is ported by hand as ``restartObservation()``, which `HomeRoute`'s `.task` calls on every
//   appearance (plan ruling 3, the `VitalsViewModel.restartHistoryObservation()` precedent).
//   Divergence (e): Android re-captures after a five-second unsubscribed grace, iOS on every
//   appearance.
//
// **Two dependencies are narrower than Kotlin's, and the ViewModel is where that shows.** Android
// takes `AiSummaryRepository` and `PremiumRepository` whole and reads one member off each
// (`HomeViewModel.kt:18-19`, `:30-31`); iOS takes ``HomeAiSummaryAvailability`` and
// ``HomePremiumStatus``, one property apiece — see those two files for why. `premiumStatus.isEntitled`
// is therefore already collapsed to a boolean at the boundary rather than re-derived here.

import Observation
import SalusCommon
import SalusModel

/// Drives the dashboard (`HomeViewModel.kt:18-69`).
@MainActor
@Observable
public final class HomeViewModel {
    /// `HomeViewModel.kt:25` — what the screen draws.
    public private(set) var state = HomeUiState()

    private let repository: any TodayRepository
    private let aiSummaryAvailability: any HomeAiSummaryAvailability
    private let premiumStatus: any HomePremiumStatus
    private let clock: any SalusClock
    private let doseActions: any DoseActions

    /// The collection. Boxed so `deinit` can cancel it — see `CancellationBox`.
    private let observation = CancellationBox()

    /// Five parameters, which are the five Koin resolves for `viewModelOf(::HomeViewModel)`
    /// (`HomeModule.kt:22`), in the Kotlin order.
    public init(
        repository: any TodayRepository,
        aiSummaryAvailability: any HomeAiSummaryAvailability,
        premiumStatus: any HomePremiumStatus,
        clock: any SalusClock,
        doseActions: any DoseActions
    ) {
        self.repository = repository
        self.aiSummaryAvailability = aiSummaryAvailability
        self.premiumStatus = premiumStatus
        self.clock = clock
        self.doseActions = doseActions
        restartObservation()
    }

    deinit {
        observation.cancel()
    }

    /// `HomeViewModel.kt:47-58`.
    public func onEvent(_ event: HomeEvent) {
        switch event {
        case let .takeDose(scheduleId, minuteOfDay):
            // Read here rather than inside the task: Kotlin reads the clock inside the coroutine,
            // but the day a tap belongs to is the day the tap happened on, and a `Task` that is
            // scheduled across midnight would otherwise stamp the write with tomorrow.
            let epochDay = clock.todayEpochDay()
            Task { [doseActions] in
                // Divergence (c): a failed write is swallowed, as everywhere else in this port.
                // Kotlin's `viewModelScope.launch` lets the exception reach the coroutine handler,
                // which on Android means a crash in debug and a silent drop in release; neither
                // platform tells the user, and neither has a retry affordance.
                try? await doseActions.markTaken(
                    scheduleId: scheduleId,
                    epochDay: epochDay,
                    minuteOfDay: minuteOfDay
                )
            }
        }
    }

    /// Re-runs the whole join, which re-captures "today" (plan ruling 3).
    ///
    /// **Why this is public.** `TodayRepositoryImpl.observeTodayOverview()` reads
    /// `clock.todayEpochDay()`, `clock.minuteOfDayNow()` and `clock.nowEpochMilliseconds()` **once,
    /// when the stream is created** — the dose window, the appointment horizon and the 30-day weight
    /// range are all fixed there and then. Android re-creates that stream whenever the state flow
    /// re-subscribes (`SharingStarted.WhileSubscribed(5_000)`, `HomeViewModel.kt:41-45`, whose
    /// comment says as much); `@Observable` has no such hook, so `HomeRoute` calls this from its
    /// `.task`, which SwiftUI re-runs on every appearance.
    ///
    /// The previous collection is cancelled and the state is **left standing** until the new one
    /// emits — which is what `stateIn` holds on to across a restart, so a returning screen never
    /// flashes its spinner.
    public func restartObservation() {
        // Each source is read once: all three build a fresh stream per access, so a second read
        // would open a second observation of the same data.
        let triples = latestOfThree(
            repository.observeTodayOverview(),
            throwingStream(over: aiSummaryAvailability.freeSummaryAvailable),
            throwingStream(over: premiumStatus.isPremium)
        )
        observation.replace(with: Task { [weak self] in
            do {
                for try await (overview, freeAiSummaryAvailable, isPremium) in triples {
                    guard let self, !Task.isCancelled else { return }
                    publish(
                        overview: overview,
                        freeAiSummaryAvailable: freeAiSummaryAvailable,
                        isPremium: isPremium
                    )
                }
            } catch {
                // A failing `Flow` cancels its collector on Android and the screen keeps whatever it
                // last drew; the same happens here, and it is this port's house pattern — there is
                // no retry affordance on either platform, so there is nothing the user could act on.
                // A failure before the first triple leaves `isLoading` true and the screen spinning,
                // which is what Android's `stateIn` initial value does too.
            }
        })
    }

    /// `combine`'s lambda (`HomeViewModel.kt:30-40`).
    private func publish(overview: TodayOverview, freeAiSummaryAvailable: Bool, isPremium: Bool) {
        state = HomeUiState(
            isLoading: false,
            // Read per emission, exactly where Kotlin reads it (`HomeViewModel.kt:32-33`).
            todayEpochDay: clock.todayEpochDay(),
            greeting: Self.greeting(forHour: clock.minuteOfDayNow() / 60),
            doses: overview.doses,
            appointments: overview.appointments,
            cycle: overview.cycle,
            vitals: overview.vitals,
            freeAiSummaryAvailable: freeAiSummaryAvailable,
            isPremium: isPremium
        )
    }

    /// `HomeViewModel.kt:61-68` — the four buckets, verbatim.
    ///
    /// The hour comes from `clock.minuteOfDayNow() / 60` where Kotlin reads
    /// `clock.localTimeNow().hour`: `SalusClock` ports `LocalTime` as a minute of day (see its
    /// `minuteOfDayNow()`), and integer division is the same number.
    private static func greeting(forHour hour: Int) -> HomeGreeting {
        switch hour {
        case 5 ... 11: .morning
        case 12 ... 17: .afternoon
        case 18 ... 22: .evening
        // 23 and 0...4.
        default: .night
        }
    }
}
