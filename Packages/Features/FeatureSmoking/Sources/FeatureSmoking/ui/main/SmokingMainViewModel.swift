// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// SmokingMainViewModel.kt`.
//
// `MutableStateFlow` + `update { it.copy(…) }` becomes an `@Observable` `state` mutated in place;
// `viewModelScope.launch` becomes a `Task` inside a `@MainActor` type; the buffered effect `Channel`
// becomes `pendingEffects` + `consumeEffects()` (`SmokingSetupViewModel`'s shape).
//
// Not ported: `runClock`. The counters between two snapshots are moved by the view's
// `TimelineView` (see `SmokingMainTime.swift`), so the ViewModel holds no ticker and no
// `liveNowMs`.

import Foundation
import Observation
import SalusCommon
import SalusNavigation
import SalusSmoking

/// The main screen. The snapshot comes from the repository (recomputed there once a minute and on
/// every write).
///
/// Both sheets write through use cases and say so on failure: a refused write leaves the state as
/// it was and queues an error effect. `writing` is set before the write starts, so a second tap of
/// a confirm button while the first is in flight does nothing — on the restart path too, where a
/// second `ResolveSlip` would close the new attempt and open a third.
@MainActor
@Observable
public final class SmokingMainViewModel {
    public private(set) var state = SmokingMainUiState()

    /// Errors waiting for the Route to show them, oldest first.
    public private(set) var pendingEffects: [SmokingMainEffect] = []

    private let clock: any SalusClock
    private let resolveSlip: ResolveSlip
    private let editEvent: EditEvent
    private let navigator: Navigator

    /// The slip the trigger sheet is about. `EditEvent` rewrites the whole entry, so the time and
    /// the units it was logged with have to come back with the trigger; the sheet itself only
    /// names the event.
    private var lastSlip: LoggedSlip?

    /// The snapshot observation, held so `deinit` can cancel it — a `CancellationBox` because a
    /// `@MainActor` class cannot read its own stored properties from `deinit` in Swift 6.0.
    private let observation = CancellationBox()

    public init(
        repository: any SmokingRepository,
        clock: any SalusClock,
        resolveSlip: ResolveSlip,
        editEvent: EditEvent,
        navigator: Navigator
    ) {
        self.clock = clock
        self.resolveSlip = resolveSlip
        self.editEvent = editEvent
        self.navigator = navigator

        let snapshots = repository.observeSnapshot()
        observation.replace(with: Task { [weak self] in
            for await snapshot in snapshots {
                guard let self, !Task.isCancelled else { return }
                state.snapshot = snapshot
            }
        })
    }

    deinit {
        observation.cancel()
    }

    /// Drains the queued effects in order, leaving the queue empty.
    @discardableResult
    public func consumeEffects() -> [SmokingMainEffect] {
        let drained = pendingEffects
        pendingEffects.removeAll()
        return drained
    }

    /// One case per event, as in the Kotlin `when`; the arms are one-liners.
    public func onEvent(_ event: SmokingMainEvent) {
        switch event {
        case .cravingTapped:
            navigator.navigate(SmokingCravingKey(source: Self.cravingSource))

        case .smokedTapped:
            state.sheet = .slip(units: Self.defaultSlipUnits)

        case let .slipConfirmed(units, restart):
            confirmSlip(units: units, restart: restart)

        // Not while its confirm is in flight: the write is already on its way and lands in the
        // trigger sheet, which a vanished slip sheet would leave opening out of nowhere.
        case .slipDismissed:
            if case .slip = state.sheet, !state.writing {
                state.sheet = nil
            }

        case let .triggerSaved(trigger, intensity):
            saveTrigger(trigger: trigger, intensity: intensity)

        case .triggerSkipped:
            closeTriggerSheet()

        case .stageTapped:
            if case let .quit(quit) = state.snapshot, let stage = quit.nextStage {
                navigator.navigate(SmokingTimelineKey(highlightStageId: stage.stageId))
            }

        case .historyTapped:
            navigator.navigate(SmokingHistoryKey())

        case .settingsTapped:
            navigator.navigate(SmokingSettingsKey())

        // The goal card and the insights card are filled by the premium task; the Route opens
        // Trends itself, since that screen belongs to another feature.
        case .goalTapped, .insightsTapped:
            break
        }
    }

    private func confirmSlip(units: Int, restart: Bool) {
        guard !state.writing, case .slip = state.sheet else { return }
        state.writing = true
        let atMs = clock.nowEpochMilliseconds()
        Task { [weak self, resolveSlip] in
            do {
                let eventId = try await resolveSlip(units: Int64(units), atMs: atMs, restart: restart)
                self?.slipWritten(LoggedSlip(eventId: eventId, atMs: atMs, units: units))
            } catch {
                self?.failed()
            }
        }
    }

    private func slipWritten(_ slip: LoggedSlip) {
        lastSlip = slip
        state.writing = false
        state.sheet = .trigger(eventId: slip.eventId)
    }

    private func saveTrigger(trigger: CravingTrigger?, intensity: Int?) {
        guard !state.writing, case let .trigger(eventId) = state.sheet else { return }
        let slip = lastSlip.flatMap { $0.eventId == eventId ? $0 : nil }
        // Nothing chosen, or an entry this screen did not write: there is nothing to add to it.
        guard let slip, trigger != nil || intensity != nil else {
            closeTriggerSheet()
            return
        }
        state.writing = true
        Task { [weak self, editEvent] in
            do {
                try await editEvent(
                    eventId: slip.eventId,
                    atMs: slip.atMs,
                    units: Int64(slip.units),
                    trigger: trigger,
                    intensity: intensity
                )
                self?.triggerSaved()
            } catch {
                self?.failed()
            }
        }
    }

    private func triggerSaved() {
        lastSlip = nil
        state.writing = false
        state.sheet = nil
    }

    private func closeTriggerSheet() {
        lastSlip = nil
        if case .trigger = state.sheet {
            state.sheet = nil
        }
    }

    /// A refused write: the state is as it was, only the busy flag drops, and the person is told.
    private func failed() {
        state.writing = false
        pendingEffects.append(.showError)
    }

    private struct LoggedSlip {
        let eventId: String
        let atMs: Int64
        let units: Int
    }

    private static let cravingSource = "main"
    private static let defaultSlipUnits = 1
}
