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
//
// **The reminder readiness is not part of the join, and on Android it is.** Kotlin combines a
// fourth source — a `MutableStateFlow<ReminderReadinessReport?>` — into the `combine` that builds
// the state, because a `StateFlow` is the only way its state can change. Here the state is an
// `@Observable` property this class owns outright, so ``refreshReminderReadiness()`` writes the
// field on the standing state directly and ``publish(overview:freeAiSummaryAvailable:isPremium:)``
// carries the stored answer forward. Same two rules on both sides: the device is re-read on every
// ``HomeEvent/appeared`` and never as part of a repository emission, and a healthy device is
// stored as nil so no card is drawn.

import Observation
import SalusCommon
import SalusModel
import SalusReminder
import SalusSettings

/// Drives the dashboard (`HomeViewModel.kt:18-69`).
@MainActor
@Observable
public final class HomeViewModel {
    /// `HomeViewModel.kt:25` — what the screen draws.
    public private(set) var state = HomeUiState()

    /// One-shot work for the Route, in order (in-app review spec §3). The `MoreViewModel` shape:
    /// Kotlin's buffered `Channel<HomeEffect>` becomes an array the Route drains with
    /// ``consumeEffects()``; nothing is dropped.
    public private(set) var pendingEffects: [HomeEffect] = []

    private let repository: any TodayRepository
    private let aiSummaryAvailability: any HomeAiSummaryAvailability
    private let premiumStatus: any HomePremiumStatus
    private let clock: any SalusClock
    private let doseActions: any DoseActions
    private let environment: any ReminderEnvironment
    /// Whether this OS has AlarmKit at all, decided by the shell — see
    /// ``SalusReminder/ReminderEnvironment/readiness(alarmKitSupported:)``, which stays pure by
    /// never asking.
    private let alarmKitSupported: Bool
    private let preferences: SalusPreferencesDataSource
    private let foreground: AppForegroundSignal

    /// The last answer ``refreshReminderReadiness()`` got, nil for a healthy device. Held apart
    /// from ``state`` so a repository emission republishes it instead of clearing it — Kotlin gets
    /// the same by making it the fourth `combine` source (`HomeViewModel.kt:47`).
    private var reminderReadiness: ReminderReadinessReport?

    /// The collection. Boxed so `deinit` can cancel it — see `CancellationBox`.
    private let observation = CancellationBox()
    /// The foreground subscription, released in `deinit`.
    @ObservationIgnored private var foregroundSubscription: AppForegroundSignal.Subscription?
    /// Whether the dashboard is on screen. A foreground return counts as an "open" only while it
    /// is — Android's `LifecycleResumeEffect` only fires for the composed tab, and this is its twin.
    @ObservationIgnored private var isVisible = false

    /// Nine parameters: the five Koin resolves for `viewModelOf(::HomeViewModel)`
    /// (`HomeModule.kt:22`), in the Kotlin order, plus the readiness card's two — the environment
    /// Kotlin also takes (`HomeViewModel.kt:40`) and the AlarmKit availability that has no Kotlin
    /// twin, because AlarmKit exists only from iOS 26 and the classification refuses to decide
    /// that itself — plus the review prompt's two: the preferences that hold its counters and the
    /// shell's foreground signal (`AppForegroundSignal`, iOS-only).
    public init(
        repository: any TodayRepository,
        aiSummaryAvailability: any HomeAiSummaryAvailability,
        premiumStatus: any HomePremiumStatus,
        clock: any SalusClock,
        doseActions: any DoseActions,
        environment: any ReminderEnvironment,
        alarmKitSupported: Bool,
        preferences: SalusPreferencesDataSource,
        foreground: AppForegroundSignal
    ) {
        self.repository = repository
        self.aiSummaryAvailability = aiSummaryAvailability
        self.premiumStatus = premiumStatus
        self.clock = clock
        self.doseActions = doseActions
        self.environment = environment
        self.alarmKitSupported = alarmKitSupported
        self.preferences = preferences
        self.foreground = foreground
        restartObservation()
        foregroundSubscription = foreground.subscribe { [weak self] in
            self?.sceneDidBecomeActive()
        }
    }

    deinit {
        observation.cancel()
        // `deinit` is nonisolated; the signal is main-actor bound, and a ViewModel is only ever
        // released on the main actor (it is a view's `@State`), so the hop is a formality.
        //
        // It is not free, though: between this `deinit` and the `Task` running, the signal still
        // holds a handler whose `self` is gone. Harmless by construction — the capture is `[weak
        // self]`, so a fan-out in that window calls nothing — but it does mean the handler count
        // is not an assertion anything may rely on, and it is why the closure below captures the
        // signal and the subscription rather than reaching through `self`.
        if let foregroundSubscription {
            let foreground = foreground
            Task { @MainActor in foreground.unsubscribe(foregroundSubscription) }
        }
    }

    /// The shell's `.active` arm reached this ViewModel (through `AppForegroundSignal`).
    ///
    /// A subscription rather than a second `scenePhase` reader: `SalusApp` owns the one `onChange`
    /// the graph is driven from (`SalusApp.swift`), and SwiftUI does not re-run a `.task` for a
    /// foreground return — so without this the dashboard would keep showing a card for a permission
    /// the user has just gone to Settings and granted. Counts as an open only while the dashboard
    /// is showing.
    public func sceneDidBecomeActive() {
        guard isVisible else { return }
        onEvent(.appeared)
    }

    /// The Route left the screen; a foreground return until the next `.appeared` does not count.
    public func didDisappear() {
        isVisible = false
    }

    /// Drains the queue (`MoreViewModel.consumeEffects()`).
    public func consumeEffects() -> [HomeEffect] {
        let drained = pendingEffects
        pendingEffects.removeAll()
        return drained
    }

    /// `HomeViewModel.kt:47-58`, plus `.appeared` for the readiness card and the review prompt.
    public func onEvent(_ event: HomeEvent) {
        switch event {
        case .appeared:
            isVisible = true
            requestReviewIfDue()
            // Device state the user toggles outside our process, re-read on every arrival
            // (`HomeViewModel.kt:92-94`). `readiness` is `async` here where Kotlin's is blocking —
            // `UNUserNotificationCenter` only answers through a callback — so it is a `Task`, and a
            // second `.appeared` before the first finishes simply writes the same answer twice.
            Task { [weak self] in
                await self?.refreshReminderReadiness()
            }

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
        // Cancelled **before** the new sources are built, rather than left to `replace(with:)`
        // afterwards: `observeTodayOverview()` registers its four DAO observations the moment it is
        // called, so building first would hold two complete joins open over the same tables until
        // `replace` got around to dropping the old task. `flatMapLatest` cancels the inner flow
        // before it starts the next one, and so does `VitalsViewModel.restartHistoryObservation()`.
        observation.cancel()
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

    /// The review prompt (in-app review spec §3): every arrival counts, and the request goes out
    /// when `ReviewPromptPolicy` says so. The stamp is written **before** the effect is queued, so
    /// a request the platform swallows — or a crash between the two — still consumes the 14-day
    /// slot; that is the conservative reading of both stores' quota guidance.
    private func requestReviewIfDue() {
        let count = preferences.incrementHomeOpenCount()
        let last = preferences.reviewState().lastRequestedEpochMs
        let now = clock.nowEpochMilliseconds()
        guard ReviewPromptPolicy.shouldRequest(openCount: count, lastRequestedEpochMs: last, nowEpochMs: now) else {
            return
        }
        preferences.setReviewLastRequested(epochMs: now)
        pendingEffects.append(.requestReview)
    }

    /// Re-reads the device and stores the answer (`HomeViewModel.kt:112-115`).
    ///
    /// A healthy device is stored as nil, which is what makes the card disappear on the arrival
    /// after the user fixed the setting: the screen draws the card for a non-nil report and for
    /// nothing else, so "no problems" and "not asked yet" are deliberately the same state.
    ///
    /// Both the field and the standing state are written, because a report that only reached the
    /// field would wait for the next repository emission to be seen — and the join emits when the
    /// data changes, which a permission grant does not do.
    private func refreshReminderReadiness() async {
        let report = await environment.readiness(alarmKitSupported: alarmKitSupported)
        let unhealthy = report.readiness == .ok ? nil : report
        reminderReadiness = unhealthy
        state.reminderReadiness = unhealthy
    }

    /// `combine`'s lambda (`HomeViewModel.kt:30-40`).
    private func publish(overview: TodayOverview, freeAiSummaryAvailable: Bool, isPremium: Bool) {
        state = HomeUiState(
            isLoading: false,
            // Read per emission, exactly where Kotlin reads it (`HomeViewModel.kt:32-33`).
            todayEpochDay: clock.todayEpochDay(),
            greeting: Self.greeting(forHour: clock.minuteOfDayNow() / 60),
            profileName: overview.profileName,
            doseProgress: Self.doseProgress(for: overview.doses),
            doses: overview.doses,
            appointments: overview.appointments,
            cycle: overview.cycle,
            vitals: overview.vitals,
            freeAiSummaryAvailable: freeAiSummaryAvailable,
            isPremium: isPremium,
            // Carried forward rather than re-read: the device is asked on `.appeared` only, and a
            // repository emission is not one. Kotlin's fourth `combine` source does the same.
            reminderReadiness: reminderReadiness
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

    /// `HomeViewModel.kt:73-79` — taken-plus-snoozed over total, nil when there are no doses.
    private static func doseProgress(for doses: [TodayDose]) -> (taken: Int, total: Int)? {
        guard doses.isEmpty == false else { return nil }
        let taken = doses.count { $0.status == .taken || $0.status == .snoozed }
        return (taken: taken, total: doses.count)
    }
}
