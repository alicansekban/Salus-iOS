// Ported from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/appointments/
// ui/list/AppointmentsViewModel.kt`.
//
// How the Kotlin flow graph is spelled in Swift, piece by piece:
//
//   `combine(observeUpcoming(now), observePast(now), pendingDeletes.pendingIds) { … }` — two of the
//   three sources are `AsyncThrowingStream`s and the third is an `@Observable` property, so there
//   is no single operator to reach for. Each is observed on its own and all three write into
//   `republish()`, which is what `combine`'s lambda was: the latest of each, folded into one state.
//   `combine` emits nothing until *every* source has produced a value, which is why `republish()`
//   returns early while either `loadedUpcoming` or `loadedPast` is nil — a `pendingIds` change
//   arriving before the first repository emission must not paint a half-empty agenda over the
//   initial loading state.
//
//   `pendingDeletes.pendingIds` is not a stream at all: it is an `@Observable` property, so it is
//   read inside `withObservationTracking`, whose `onChange` fires **once** and must therefore
//   re-register itself. `onChange` also runs *before* the new value is stored, which is why the
//   re-registration hops through a `Task { @MainActor }` and why a test reads the list through
//   `waitUntil` rather than straight after a delete. This is `VitalsViewModel.trackPendingDeletes`,
//   unchanged.
//
//   `.stateIn(scope, WhileSubscribed(5_000), AppointmentsUiState())` — `@Observable` has no
//   subscription-count hook, so the observation runs from `init` to `deinit` instead of starting
//   and stopping with the UI. The initial value is the same `AppointmentsUiState()`, and `deinit`
//   cancels both collections through `CancellationBox`.
//
// **ONE BEHAVIOURAL DIVERGENCE, deliberate and recorded.** Kotlin hangs the whole graph off
// `isPastExpanded.flatMapLatest { … }` (`AppointmentsViewModel.kt:29-32`), so every tap on
// "show/hide past" tears the two collections down and reopens them with a **fresh** `clock.now()`
// and `clock.today()`. Here `now` and `todayEpochDay` are captured once, in `init`, and the toggle
// only flips a flag and republishes. Two reasons: the flag is presentation state that the
// repository query does not depend on — restarting two database observations to redraw a
// disclosure arrow is a side effect of how `flatMapLatest` was reached for, not a behaviour anyone
// asked for — and a restart would drop the agenda back to its loading state mid-interaction, which
// on Android is hidden by `stateIn` holding the last value and here would be visible. What Android
// buys with it is a clock refresh; the same refresh arrives on iOS the way it does everywhere in
// this port, by the Route rebuilding the ViewModel when the screen is entered again. Neither
// platform refreshes `now` while the list sits open.

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

    /// What each window has emitted, or nil while it has emitted nothing yet — the state `combine`
    /// is in before all of its sources have produced a value.
    private var loadedUpcoming: [Appointment]?
    private var loadedPast: [Appointment]?

    /// The two collections. Boxed so `deinit` can cancel them — see `CancellationBox`.
    private let upcomingTask = CancellationBox()
    private let pastTask = CancellationBox()

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
        upcomingTask.cancel()
        pastTask.cancel()
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
        observe(repository.observeUpcoming(from: now), into: upcomingTask) { viewModel, items in
            viewModel.loadedUpcoming = items
        }
        observe(repository.observePast(before: now), into: pastTask) { viewModel, items in
            viewModel.loadedPast = items
        }
    }

    /// One arm of `combine`: every emission is stored, then the three latest values are folded.
    private func observe(
        _ stream: AsyncThrowingStream<[Appointment], any Error>,
        into box: CancellationBox,
        store: @escaping @MainActor (AppointmentsViewModel, [Appointment]) -> Void
    ) {
        box.replace(with: Task { [weak self] in
            do {
                for try await items in stream {
                    guard let self else { return }
                    store(self, items)
                    republish()
                }
            } catch {
                // A failing `Flow` cancels its collector on Android and the screen keeps whatever
                // it last drew; the same happens here. Nothing is swallowed that the user could
                // have acted on — there is no retry affordance on either platform.
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
        guard let loadedUpcoming, let loadedPast else { return }
        let pending = pendingDeletes.pendingIds
        state = AppointmentsUiState(
            isLoading: false,
            upcoming: Self.groupIntoDays(Self.listItems(loadedUpcoming, without: pending)),
            past: Self.listItems(loadedPast, without: pending),
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
