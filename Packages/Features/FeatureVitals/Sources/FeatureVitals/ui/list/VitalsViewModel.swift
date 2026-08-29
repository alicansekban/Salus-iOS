// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/list/VitalsViewModel.kt`.
//
// **Constructor parity, closed in iOS-M7.** Android's is `VitalsViewModel(repository, preferences,
// pendingDeletes, undoableDelete, clock)` and so is this one, in the same order. iOS-M2 shipped it
// without `preferences` because `VitalsPreferences` (and `VitalsPreferencesImpl` over the
// `glucose_unit` key in `SalusSettings`) was M7 work; M7 brought both, so the divergence this
// comment used to record no longer exists.
//
// How the Kotlin flow graph is spelled in Swift, piece by piece:
//
//   `combine(selectedType, selectedRange).flatMapLatest { … }` — the two selections are plain
//   stored properties, and `onEvent` restarts the observation when either changes. `flatMapLatest`
//   is `historyTask?.cancel()` at the top of that restart.
//
//   `combine(repository.observeWeightHistory(…), pendingDeletes.pendingIds)` — one source is an
//   `AsyncThrowingStream` and the other is an `@Observable` property, so there is no single
//   operator to reach for. Each is observed on its own and both write into `republish()`, which is
//   what `combine`'s lambda was: the latest of each, folded into one state. `combine` emits nothing
//   until *every* source has produced a value, which is why `republish()` returns early while
//   `loadedEntries` is nil — a pendingIds change arriving between a range switch and the new
//   window's first emission must not repaint the list with the old window's rows. The glucose
//   branch has a **third** source, `preferences.glucoseUnit` (`VitalsViewModel.kt:74-81`), so it
//   also returns early while `loadedUnit` is nil: a window that emitted before the stored unit
//   arrived would draw one repaint's worth of mg/dL rows to a reader who asked for mmol/L.
//
//   `.combine(pendingDeleteId) { state, id -> state.copy(pendingDeleteId = id) }` — the outer
//   combine is `publish()`, which stamps the confirmation id onto whatever the inner state last
//   was. Keeping it outside `republish()` is what lets the dialog open without waiting for a
//   repository emission.
//
//   `.stateIn(scope, WhileSubscribed(5_000), VitalsUiState())` — `@Observable` has no
//   subscription-count hook, so the observation runs from `init` to `deinit` instead of starting
//   and stopping with the UI. The initial value is the same `VitalsUiState()`. The half of
//   `WhileSubscribed` that *is* load-bearing — re-running `flatMapLatest` with a fresh
//   `clock.now()` when the list re-subscribes — is ported by hand as
//   `restartHistoryObservation()`, which `VitalsRoute.task` calls on every appearance.

import Foundation
import Observation
import SalusCommon
import SalusModel
import SalusUI

/// Drives the vitals list (`VitalsViewModel.kt:39-247`).
///
/// All three vital types are built here since iOS-M7: weight and blood pressure from their history
/// plus the pending deletes, glucose from those two plus the stored display unit.
@MainActor
@Observable
public final class VitalsViewModel {
    /// `VitalsViewModel.kt:51` — what the screen draws.
    public private(set) var state = VitalsUiState()

    private let repository: any VitalsRepository
    private let preferences: any VitalsPreferences
    private let pendingDeletes: PendingDeleteController
    private let undoableDelete: UndoableDelete
    /// Internal rather than private because the state builders read the zone off it and live in
    /// `VitalsStateBuilders.swift`; `private` would reach an extension in this file only.
    let clock: any SalusClock

    /// `VitalsViewModel.kt:47-49`.
    private var selectedType: VitalType = .weight
    private var selectedRange: ChartRange = .month
    private var pendingDeleteId: String?

    /// The inner flow's latest value, before the confirmation id is stamped on.
    private var listState = VitalsUiState()

    /// What the current window has emitted, or nil while it has emitted nothing yet — the state
    /// `combine` is in before all of its sources have produced a value. Tagged with the branch it
    /// came from, so a late emission from the window a type switch just cancelled cannot be folded
    /// through the new type's builder.
    private var loadedEntries: LoadedVitalsHistory?

    /// The glucose branch's third source (`VitalsViewModel.kt:74-81`), nil on the same terms and
    /// left nil by the other two branches, which never read it.
    private var loadedUnit: GlucoseUnit?

    /// The current window's collection. Boxed so `deinit` can cancel it — see `CancellationBox`.
    private let historyTask = CancellationBox()

    /// The glucose branch's unit collection, restarted and cancelled with the window it belongs to.
    private let unitTask = CancellationBox()

    public init(
        repository: any VitalsRepository,
        preferences: any VitalsPreferences,
        pendingDeletes: PendingDeleteController,
        undoableDelete: UndoableDelete,
        clock: any SalusClock
    ) {
        self.repository = repository
        self.preferences = preferences
        self.pendingDeletes = pendingDeletes
        self.undoableDelete = undoableDelete
        self.clock = clock
        start()
    }

    deinit {
        historyTask.cancel()
        unitTask.cancel()
    }

    /// `VitalsViewModel.kt:93-103`.
    public func onEvent(_ event: VitalsEvent) {
        switch event {
        case let .typeSelected(type):
            // A `MutableStateFlow` assigned its current value emits nothing, so re-selecting the
            // type or range must not restart the window (`VitalsViewModel.kt:95-96`).
            guard type != selectedType else { return }
            selectedType = type
            restartHistoryObservation()

        case let .rangeSelected(range):
            guard range != selectedRange else { return }
            selectedRange = range
            restartHistoryObservation()

        case let .deleteRequested(id):
            pendingDeleteId = id
            publish()

        case .deleteDismissed:
            pendingDeleteId = nil
            publish()

        case .deleteConfirmed:
            confirmDelete()
        }
    }

    private func start() {
        trackPendingDeletes()
        restartHistoryObservation()
    }

    /// `VitalsViewModel.kt:105-116`.
    private func confirmDelete() {
        guard let id = pendingDeleteId else { return }
        pendingDeleteId = nil
        publish()
        let type = selectedType
        // The message is resolved here rather than passed as a key: a feature's strings live in its
        // own `Bundle.module` and the shell that draws the snackbar cannot reach them
        // (`UndoableDelete.swift:18-24`).
        undoableDelete(id, message: VitalsStrings.entryDeleted) { [repository] in
            switch type {
            case .weight:
                // Kotlin lets a repository failure propagate into `viewModelScope`; there is no
                // such scope here, and a delete that failed has already been taken off the list, so
                // the row simply comes back on the next emission. The same holds for the two arms
                // below.
                try? await repository.deleteWeightEntry(id: id)
            case .bloodPressure:
                try? await repository.deleteBloodPressureEntry(id: id)
            case .bloodGlucose:
                try? await repository.deleteGlucoseEntry(id: id)
            }
        }
    }

    /// The twin of `flatMapLatest`: the previous window's collection is cancelled and a new one
    /// starts (`VitalsViewModel.kt:52-83`), recomputing `until` from the clock
    /// (`VitalsViewModel.kt:53`) while keeping the current type and range.
    ///
    /// **Why this is public.** The window is `BETWEEN from AND until`, and `until` is a *fixed*
    /// instant taken when the window opened — so an entry saved afterwards
    /// (`measuredAt > until`) falls outside it and never arrives. Android never sees this because
    /// `.stateIn(scope, SharingStarted.WhileSubscribed(5_000), VitalsUiState())`
    /// (`VitalsViewModel.kt:87-90`) *stops* collecting once the list leaves composition and
    /// re-runs the whole `combine(selectedType, selectedRange).flatMapLatest { … }`
    /// (`VitalsViewModel.kt:51-52`) — with a fresh `clock.now()` — when the screen re-subscribes
    /// after the editor pops. `@Observable` has no subscription-count hook, so the collection here
    /// runs from `init` to `deinit`; `VitalsRoute` calls this from its `.task`, which SwiftUI
    /// re-runs on every appearance, to port those re-subscribe semantics by hand.
    public func restartHistoryObservation() {
        historyTask.cancel()
        unitTask.cancel()
        // `combine` starts over: the new window has emitted nothing yet, so the previous state
        // stands until it does — which is exactly what `stateIn` holds on to across a restart.
        loadedEntries = nil
        loadedUnit = nil

        let until = clock.now()
        let from = until.addingTimeInterval(-Double(selectedRange.days) * secondsPerDay)

        // The `when (type)` of `VitalsViewModel.kt:55-82`, one inner flow per type.
        switch selectedType {
        case .weight:
            observe(repository.observeWeightHistory(from: from, until: until)) { .weight($0) }
        case .bloodPressure:
            observe(repository.observeBloodPressureHistory(from: from, until: until)) { .bloodPressure($0) }
        case .bloodGlucose:
            observe(repository.observeGlucoseHistory(from: from, until: until)) { .glucose($0) }
            observeGlucoseUnit()
        }
    }

    /// Collects one window's history into the fold, tagged with the branch that asked for it.
    ///
    /// `Task.isCancelled` is the second half of `flatMapLatest`: `historyTask.replace` cancels the
    /// task the previous window left running, and this stops a value that was already buffered
    /// when the cancellation landed from writing the old branch's rows into the new one's fold.
    private func observe<Entry: Sendable>(
        _ history: AsyncThrowingStream<[Entry], any Error>,
        as tag: @escaping @Sendable ([Entry]) -> LoadedVitalsHistory
    ) {
        historyTask.replace(with: Task { [weak self] in
            do {
                for try await entries in history {
                    guard let self, !Task.isCancelled else { return }
                    loadedEntries = tag(entries)
                    republish()
                }
            } catch {
                // A failing `Flow` cancels its collector on Android and the screen keeps whatever
                // it last drew; the same happens here. Nothing is swallowed that the user could
                // have acted on — there is no retry affordance on either platform.
            }
        })
    }

    /// The glucose branch's `preferences.glucoseUnit` source (`VitalsViewModel.kt:76`).
    private func observeGlucoseUnit() {
        let units = preferences.glucoseUnit
        unitTask.replace(with: Task { [weak self] in
            for await unit in units {
                guard let self, !Task.isCancelled else { return }
                loadedUnit = unit
                republish()
            }
        })
    }

    /// Re-registers itself after every change, because `withObservationTracking` fires once.
    ///
    /// This is the `pendingIds` half of the inner `combine` (`VitalsViewModel.kt:56-64`).
    /// `onChange` runs *before* the new value is stored, so the read happens one hop later — which
    /// is why a test reads the list through `waitUntil` rather than straight after the delete.
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

    /// The inner `combine`'s lambda: the latest window folded together with the latest pending ids,
    /// and — on the glucose branch — the latest stored unit.
    ///
    /// `entries.filterNot { it.id in pending }` (`VitalsViewModel.kt:63, 71, 80`) is folded in here
    /// rather than at the end so the chart and the list agree while an undo window is open.
    private func republish() {
        guard let loadedEntries else { return }
        let pending = pendingDeletes.pendingIds
        switch loadedEntries {
        case let .weight(entries):
            listState = buildWeightState(
                range: selectedRange,
                entries: entries.filter { !pending.contains($0.id) }
            )

        case let .bloodPressure(entries):
            listState = buildBloodPressureState(
                range: selectedRange,
                entries: entries.filter { !pending.contains($0.id) }
            )

        case let .glucose(entries):
            // The third source has not arrived yet, so `combine` has nothing to emit.
            guard let loadedUnit else { return }
            listState = buildGlucoseState(
                range: selectedRange,
                entries: entries.filter { !pending.contains($0.id) },
                unit: loadedUnit
            )
        }
        publish()
    }

    /// The outer `combine`'s lambda (`VitalsViewModel.kt:84-86`).
    private func publish() {
        var next = listState
        next.pendingDeleteId = pendingDeleteId
        state = next
    }
}

/// `kotlin.time.Duration.Companion.days` applied to a `ChartRange` (`VitalsViewModel.kt:54`): exact
/// 24-hour days, not calendar ones, on both platforms.
private let secondsPerDay: Double = 86400

/// Which inner flow of `flatMapLatest` the fold is currently holding a value from.
///
/// Kotlin needs no such tag: `when (type)` picks one `combine` and the type of its emission is the
/// branch. Here every branch writes into the same stored property, so the branch travels with the
/// value rather than being re-derived from `selectedType` — which a cancelled window's last
/// emission would read as the *new* type.
private enum LoadedVitalsHistory: Sendable {
    case weight([WeightEntry])
    case bloodPressure([BloodPressureEntry])
    case glucose([GlucoseEntry])
}
