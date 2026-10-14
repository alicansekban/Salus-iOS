// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/timeline/
// SmokingTimelineViewModel.kt`.
//
// `MutableStateFlow` + `update { it.copy(…) }` becomes an `@Observable` `state` mutated in place;
// `viewModelScope.launch` becomes a `Task` inside a `@MainActor` type; the buffered effect `Channel`
// becomes `pendingEffects` + `consumeEffects()` (`SmokingMainViewModel`'s shape).

import Foundation
import Observation
import SalusCommon
import SalusSmoking

/// The health timeline. The rows come from the repository's snapshot (recomputed there once a
/// minute and on every write), so the "n days left" lines move without a ticker of our own: the
/// smallest unit this screen shows is the minute.
///
/// `highlightStageId` is the stage a link asked for; an id the catalog does not know (a retired
/// stage in an old notification) highlights nothing.
///
/// The only write is the REDUCE screen's switch to quitting, through ``SwitchMode``. A refused
/// write leaves the state as it was, drops the busy flag and queues an error effect; the sheet stays
/// open so the date can be corrected.
@MainActor
@Observable
public final class SmokingTimelineViewModel {
    public private(set) var state: SmokingTimelineUiState

    /// Errors waiting for the Route to show them, oldest first.
    public private(set) var pendingEffects: [SmokingTimelineEffect] = []

    private let switchMode: SwitchMode
    private let clock: any SalusClock

    /// The snapshot observation, held so `deinit` can cancel it — a `CancellationBox` because a
    /// `@MainActor` class cannot read its own stored properties from `deinit` in Swift 6.0.
    private let observation = CancellationBox()

    public init(
        highlightStageId: String?,
        repository: any SmokingRepository,
        switchMode: SwitchMode,
        clock: any SalusClock
    ) {
        self.switchMode = switchMode
        self.clock = clock
        state = SmokingTimelineUiState(
            highlightStageId: highlightStageId.flatMap { id in
                MilestoneCatalog.healthStages.contains { $0.id == id } ? id : nil
            }
        )

        let snapshots = repository.observeSnapshot()
        observation.replace(with: Task { [weak self] in
            for await snapshot in snapshots {
                guard let self, !Task.isCancelled else { return }
                state = snapshot.toTimeline(base: state)
            }
        })
    }

    deinit {
        observation.cancel()
    }

    /// Drains the queued effects in order, leaving the queue empty.
    @discardableResult
    public func consumeEffects() -> [SmokingTimelineEffect] {
        let drained = pendingEffects
        pendingEffects.removeAll()
        return drained
    }

    public func onEvent(_ event: SmokingTimelineEvent) {
        switch event {
        case let .stageTapped(stageId):
            if MilestoneCatalog.healthStages.contains(where: { $0.id == stageId }) {
                state.detailStageId = stageId
            }

        case .detailDismissed:
            state.detailStageId = nil

        case .highlightShown:
            state.highlightStageId = nil

        case .switchTapped:
            state.quitDateSheet = true
            state.initialQuitAtMs = clock.nowEpochMilliseconds()

        // Not while the switch is in flight: the write is on its way and the sheet closes with it.
        case .quitDateDismissed:
            if !state.writing {
                state.quitDateSheet = false
            }

        case let .quitDateConfirmed(quitAtMs):
            switchToQuit(quitAtMs: quitAtMs)
        }
    }

    private func switchToQuit(quitAtMs: Int64) {
        guard !state.writing, state.quitDateSheet else { return }
        state.writing = true
        Task { [weak self, switchMode] in
            do {
                try await switchMode(to: .quit, quitAtMs: quitAtMs)
                self?.switched()
            } catch {
                self?.failed(error)
            }
        }
    }

    private func switched() {
        state.writing = false
        state.quitDateSheet = false
    }

    /// A refused write: the state is as it was, only the busy flag drops, and the person is told.
    private func failed(_ error: any Error) {
        state.writing = false
        pendingEffects.append(.showError(error.setupError))
    }
}
