// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/list/VitalsViewModel.kt`.
//
// **Constructor divergence, recorded on purpose.** Android's is
// `VitalsViewModel(repository, preferences, pendingDeletes, undoableDelete, clock)`; this one omits
// `preferences`, because `VitalsPreferences` (and `VitalsPreferencesImpl` over the `glucose_unit`
// key in `SalusSettings`) is iOS-M7 work. M7 therefore changes this signature, not only the state
// builders — that is the whole reason it is written down here rather than left to be discovered.
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
//   window's first emission must not repaint the list with the old window's rows.
//
//   `.combine(pendingDeleteId) { state, id -> state.copy(pendingDeleteId = id) }` — the outer
//   combine is `publish()`, which stamps the confirmation id onto whatever the inner state last
//   was. Keeping it outside `republish()` is what lets the dialog open without waiting for a
//   repository emission.
//
//   `.stateIn(scope, WhileSubscribed(5_000), VitalsUiState())` — `@Observable` has no
//   subscription-count hook, so the observation runs from `init` to `deinit` instead of starting
//   and stopping with the UI. The initial value is the same `VitalsUiState()`.

import Foundation
import Observation
import SalusCommon
import SalusModel
import SalusUI

/// Drives the vitals list (`VitalsViewModel.kt:39-247`).
///
/// M2 builds **weight state only**. Selecting blood pressure or glucose yields the empty state
/// until M7 brings their repository members, their preferences and their builders.
@MainActor
@Observable
public final class VitalsViewModel {
    /// `VitalsViewModel.kt:51` — what the screen draws.
    public private(set) var state = VitalsUiState()

    private let repository: any VitalsRepository
    private let pendingDeletes: PendingDeleteController
    private let undoableDelete: UndoableDelete
    private let clock: any SalusClock

    /// `VitalsViewModel.kt:47-49`.
    private var selectedType: VitalType = .weight
    private var selectedRange: ChartRange = .month
    private var pendingDeleteId: String?

    /// The inner flow's latest value, before the confirmation id is stamped on.
    private var listState = VitalsUiState()

    /// What the current window has emitted, or nil while it has emitted nothing yet — the state
    /// `combine` is in before all of its sources have produced a value.
    private var loadedEntries: [WeightEntry]?

    /// The current window's collection. Boxed so `deinit` can cancel it — see `CancellationBox`.
    private let historyTask = CancellationBox()

    public init(
        repository: any VitalsRepository,
        pendingDeletes: PendingDeleteController,
        undoableDelete: UndoableDelete,
        clock: any SalusClock
    ) {
        self.repository = repository
        self.pendingDeletes = pendingDeletes
        self.undoableDelete = undoableDelete
        self.clock = clock
        start()
    }

    deinit {
        historyTask.cancel()
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
                // the row simply comes back on the next emission.
                try? await repository.deleteWeightEntry(id: id)
            case .bloodGlucose, .bloodPressure:
                // TODO(M7): `repository.deleteBloodPressureEntry` / `deleteGlucoseEntry`
                // (`VitalsViewModel.kt:112-113`). Unreachable in M2 — neither type can produce a
                // row to delete.
                break
            }
        }
    }

    /// The twin of `flatMapLatest`: the previous window's collection is cancelled and a new one
    /// starts (`VitalsViewModel.kt:52-83`).
    private func restartHistoryObservation() {
        historyTask.cancel()
        // `combine` starts over: the new window has emitted nothing yet, so the previous state
        // stands until it does — which is exactly what `stateIn` holds on to across a restart.
        loadedEntries = nil

        guard selectedType == .weight else {
            // TODO(M7): `observeBloodPressureHistory` / `observeGlucoseHistory` + their builders
            // (`VitalsViewModel.kt:66-81`). Until then the chips still switch, and the other two
            // types show their own empty state.
            loadedEntries = []
            listState = VitalsUiState(
                isLoading: false,
                selectedType: selectedType,
                selectedRange: selectedRange
            )
            publish()
            return
        }

        let until = clock.now()
        let from = until.addingTimeInterval(-Double(selectedRange.days) * secondsPerDay)
        let history = repository.observeWeightHistory(from: from, until: until)
        historyTask.replace(with: Task { [weak self] in
            do {
                for try await entries in history {
                    guard let self else { return }
                    loadedEntries = entries
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

    /// The inner `combine`'s lambda: the latest window folded together with the latest pending ids.
    private func republish() {
        guard let loadedEntries else { return }
        if selectedType == .weight {
            let pending = pendingDeletes.pendingIds
            listState = buildWeightState(
                range: selectedRange,
                // `entries.filterNot { it.id in pending }` (`VitalsViewModel.kt:63`): folded in
                // here rather than at the end so the chart and the list agree while an undo window
                // is open.
                entries: loadedEntries.filter { !pending.contains($0.id) }
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

    /// `VitalsViewModel.kt:118-144`.
    private func buildWeightState(range: ChartRange, entries: [WeightEntry]) -> VitalsUiState {
        let zone = clock.timeZone()
        let sortedAscending = entries.sorted { $0.measuredAt < $1.measuredAt }

        let items = sortedAscending
            .reversed()
            .map { entry in
                VitalsListItem.weight(
                    VitalsListItem.Weight(
                        id: entry.id,
                        measuredAt: entry.measuredAt.wallClock(in: zone),
                        kilograms: entry.kilograms,
                        note: entry.note
                    )
                )
            }

        let points = Self.dailyPoints(
            sortedAscending,
            zone: zone,
            measuredAt: { $0.measuredAt },
            yValue: { Float($0.kilograms) }
        )

        return VitalsUiState(
            isLoading: false,
            selectedType: .weight,
            entries: items,
            chart: Self.chartOrNull(points, yLabel: Self.decimalYLabel),
            selectedRange: range,
            latestKilograms: sortedAscending.last?.kilograms
        )
    }

    /// One point per day (last measurement wins) keeps the x axis monotonic
    /// (`VitalsViewModel.kt:217-227`).
    ///
    /// `associateBy` keeps the last value for a repeated key and the input is ascending, so the
    /// day's newest reading is the one plotted — `uniquingKeysWith: { _, last in last }` is that,
    /// spelled out.
    private static func dailyPoints<T>(
        _ sortedAscending: [T],
        zone: TimeZone,
        measuredAt: (T) -> Date,
        yValue: (T) -> Float
    ) -> [ChartPoint] {
        let byDay = Dictionary(
            sortedAscending.map { (measuredAt($0).wallClock(in: zone).date.epochDay, $0) },
            uniquingKeysWith: { _, last in last }
        )
        return byDay
            .map { epochDay, entry in ChartPoint(xEpochDay: epochDay, y: yValue(entry)) }
            .sorted { $0.xEpochDay < $1.xEpochDay }
    }

    /// `VitalsViewModel.kt:229-237`.
    ///
    /// The `"d MMM"` axis label is produced from the epoch day through a `DateFormatter` pinned to
    /// GMT and `Locale.current` — the twin of `LocalDate.ofEpochDay(…).format(ofPattern("d MMM",
    /// Locale.getDefault()))`. Never a `Calendar`: see `VitalsLocalDateTime.swift`.
    ///
    /// The formatter is built inside the closure rather than captured, because `xLabel` is
    /// `@Sendable` and `DateFormatter` is not.
    private static func chartOrNull(
        _ points: [ChartPoint],
        yLabel: @escaping @Sendable (Float) -> String
    ) -> ChartUiModel? {
        guard points.count >= minChartPoints else { return nil }
        return ChartUiModel(
            points: points,
            xLabel: { epochDay in LocalDate(epochDay: epochDay).formatted(pattern: "d MMM") },
            yLabel: yLabel
        )
    }

    /// `VitalsViewModel.kt:239-240` — `String.format(Locale.getDefault(), "%.1f", value)`.
    private static let decimalYLabel: @Sendable (Float) -> String = { value in
        String(format: "%.1f", locale: .current, Double(value))
    }

    /// `VitalsViewModel.kt:245-247`.
    private static let minChartPoints = 2
}

/// `kotlin.time.Duration.Companion.days` applied to a `ChartRange` (`VitalsViewModel.kt:54`): exact
/// 24-hour days, not calendar ones, on both platforms.
private let secondsPerDay: Double = 86400
