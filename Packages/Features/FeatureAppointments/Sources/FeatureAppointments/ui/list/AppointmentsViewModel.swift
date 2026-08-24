// Ported from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/appointments/
// ui/list/AppointmentsViewModel.kt`.
//
// How the Kotlin flow graph is spelled in Swift:
//
//   `combine(observeUpcoming(now), observePast(now), pendingDeletes.pendingIds) { … }` — the two
//   repository arms are `AsyncThrowingStream`s and go through `latestOfBoth`, this package's
//   `combine`-of-two, which already emits nothing until both sides have produced a value and pairs
//   every later emission with the other's latest. The third arm is an `@Observable` property, so it
//   is read inside `withObservationTracking`, whose `onChange` fires **once** and must therefore
//   re-register itself. `onChange` also runs *before* the new value is stored, which is why the
//   re-registration hops through a `Task { @MainActor }` and why a test reads the list through
//   `waitUntil` rather than straight after a delete. This is `VitalsViewModel.trackPendingDeletes`,
//   unchanged.
//
//   `.stateIn(scope, WhileSubscribed(5_000), AppointmentsUiState())` — `@Observable` has no
//   subscription-count hook, so the observation runs from `init` to `deinit` instead of starting
//   and stopping with the UI. The initial value is the same `AppointmentsUiState()`, and `deinit`
//   cancels the collection through `CancellationBox`.
//
// **ONE BEHAVIOURAL DIVERGENCE, deliberate and recorded.** Kotlin hangs the whole graph off
// `isPastExpanded.flatMapLatest { … }` (`AppointmentsViewModel.kt:29-32`), so every tap on
// "show/hide past" tears the collections down and reopens them with a **fresh** `clock.now()` and
// `clock.today()`. Here `now` and `todayEpochDay` are captured once, in `init`, and the toggle only
// flips a flag and republishes. Two reasons: the flag is presentation state that the repository
// query does not depend on — restarting two database observations to redraw a disclosure arrow is a
// side effect of how `flatMapLatest` was reached for, not a behaviour anyone asked for — and a
// restart would drop the agenda back to its loading state mid-interaction, which on Android is
// hidden by `stateIn` holding the last value and here would be visible. What Android buys with it
// is a clock refresh; the same refresh arrives on iOS the way it does everywhere in this port, by
// the Route rebuilding the ViewModel when the screen is entered again. Neither platform refreshes
// `now` while the list sits open.

import Foundation
import Observation
import SalusCommon

/// Drives the appointments agenda (`AppointmentsViewModel.kt:22-83`).
@MainActor
@Observable
public final class AppointmentsViewModel {
    /// `AppointmentsViewModel.kt:29` — what the screen draws.
    public private(set) var state = AppointmentsUiState()

    private let repository: any AppointmentsRepository
    private let pendingDeletes: PendingDeleteController

    /// `AppointmentsViewModel.kt:30-31` — read once, when the observation opens, and used for both
    /// window bounds so "upcoming" and "past" stay a partition rather than two windows that can
    /// drift apart by the microseconds between two `now()` calls.
    private let now: Date
    private let todayEpochDay: Int

    /// `AppointmentsViewModel.kt:27`.
    private var isPastExpanded = false

    /// The latest pair the two windows have formed, or nil while `latestOfBoth` has emitted nothing
    /// — the state `combine` is in before all of its sources have produced a value. A `pendingIds`
    /// change arriving before that first pair must not paint a half-empty agenda over the initial
    /// loading state, which is what `republish()`'s `guard` is for.
    private var loaded: (upcoming: [Appointment], past: [Appointment])?

    /// The collection. Boxed so `deinit` can cancel it — see `CancellationBox`.
    private let observation = CancellationBox()

    public init(
        repository: any AppointmentsRepository,
        pendingDeletes: PendingDeleteController,
        clock: any SalusClock
    ) {
        self.repository = repository
        self.pendingDeletes = pendingDeletes
        now = clock.now()
        todayEpochDay = clock.todayEpochDay()
        start()
    }

    deinit {
        observation.cancel()
    }

    /// `AppointmentsViewModel.kt:70-74`.
    public func onEvent(_ event: AppointmentsEvent) {
        switch event {
        case .togglePastSection:
            isPastExpanded.toggle()
            republish()
        }
    }

    private func start() {
        trackPendingDeletes()
        let pairs = latestOfBoth(
            repository.observeUpcoming(from: now),
            repository.observePast(before: now)
        ) { ($0, $1) }
        observation.replace(with: Task { [weak self] in
            do {
                for try await (upcoming, past) in pairs {
                    guard let self else { return }
                    loaded = (upcoming, past)
                    republish()
                }
            } catch {
                // A failing `Flow` cancels its collector on Android and the screen keeps whatever it
                // last drew; the same happens here, and it is `VitalsViewModel`'s house pattern —
                // there is no retry affordance on either platform, so there is nothing the user
                // could act on. Said plainly, because it has one visible edge: a failure *before*
                // the first pair leaves `loaded` nil, so `state.isLoading` stays true and the screen
                // spins forever rather than showing an error. Android's spinner is equally
                // permanent (`stateIn`'s initial value is the loading state and the cancelled flow
                // never replaces it), so this is the ported behaviour and not a dropped case. A
                // real error state is a product decision both platforms would take together.
            }
        })
    }

    /// Re-registers itself after every change, because `withObservationTracking` fires once.
    ///
    /// This is the `pendingIds` arm of the `combine` (`AppointmentsViewModel.kt:36`).
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

    /// `combine`'s lambda (`AppointmentsViewModel.kt:37-49`).
    ///
    /// Rows vanish the moment a delete is confirmed and come back on undo, without a repository
    /// round trip in either direction.
    private func republish() {
        guard let loaded else { return }
        let pending = pendingDeletes.pendingIds
        state = AppointmentsUiState(
            isLoading: false,
            upcoming: Self.groupIntoDays(Self.listItems(loaded.upcoming, without: pending)),
            past: Self.listItems(loaded.past, without: pending),
            isPastExpanded: isPastExpanded,
            todayEpochDay: todayEpochDay
        )
    }

    /// `filterNot { it.id in pendingIds }.map { it.toListItem() }`
    /// (`AppointmentsViewModel.kt:41-45`, `:77-83`).
    private static func listItems(
        _ appointments: [Appointment],
        without pending: Set<String>
    ) -> [AppointmentListItem] {
        appointments
            .filter { !pending.contains($0.id) }
            .map { appointment in
                AppointmentListItem(
                    id: appointment.id,
                    title: appointment.title,
                    doctorName: appointment.doctorName,
                    location: appointment.location,
                    startsAt: appointment.startsAt
                )
            }
    }

    /// `AppointmentsViewModel.kt:76-79`. The repository already sorts soonest first, so grouping
    /// preserves that order.
    ///
    /// Kotlin's `groupBy` returns a `LinkedHashMap`, whose iteration order is first-encounter of
    /// each key; a Swift `Dictionary` has no order at all, so the day keys are collected in a
    /// separate array as they are first seen. That array *is* the `LinkedHashMap`'s ordering,
    /// spelled out — without it two days could come back swapped on a rebuild.
    private static func groupIntoDays(_ items: [AppointmentListItem]) -> [AppointmentDaySection] {
        var days: [Int] = []
        var itemsByDay: [Int: [AppointmentListItem]] = [:]
        for item in items {
            let epochDay = item.startsAt.date.epochDay
            if itemsByDay[epochDay] == nil {
                days.append(epochDay)
            }
            itemsByDay[epochDay, default: []].append(item)
        }
        return days.map { epochDay in
            AppointmentDaySection(epochDay: epochDay, items: itemsByDay[epochDay] ?? [])
        }
    }
}
