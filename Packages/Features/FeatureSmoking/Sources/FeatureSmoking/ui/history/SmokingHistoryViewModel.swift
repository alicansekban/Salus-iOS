// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/history/
// SmokingHistoryViewModel.kt`.
//
// `MutableStateFlow` + `update { it.copy(…) }` becomes an `@Observable` `state` mutated in place;
// `viewModelScope.launch` becomes a `Task` inside a `@MainActor` type; the buffered effect `Channel`
// becomes `pendingEffects` + `consumeEffects()` (`SmokingMainViewModel`'s shape).
//
// `combine(observeInput(), observeSnapshot())` has no operator here: each stream's task stores its
// latest value and rebuilds the state once both have arrived, which is what `combine` emits.

import Foundation
import Observation
import SalusCommon
import SalusSmoking

/// The history screen. The log is the stored entries, bucketed by the day each was stored under
/// (contract §8.5), so a slip logged in another time zone stays on the day it was lived. The attempt
/// cards are the snapshot's own figures in QUIT; in REDUCE the snapshot describes no attempts, so
/// the closed ones are drawn from the stored rows and carry no money.
///
/// Editing and deleting go through the use cases, which re-derive each entry's attempt link; this
/// class only decides what is allowed to be sent. A refused write leaves the state as it was, drops
/// the busy flag and queues an error effect; the editor stays open so the input can be corrected.
@MainActor
@Observable
public final class SmokingHistoryViewModel {
    public private(set) var state = SmokingHistoryUiState()

    /// Errors waiting for the Route to show them, oldest first.
    public private(set) var pendingEffects: [SmokingHistoryEffect] = []

    private let editEvent: EditEvent
    private let deleteEvent: DeleteEvent
    private let clock: any SalusClock

    private var latestInput: SmokingInput?
    private var latestSnapshot: SmokingSnapshot?

    /// The two observations, held so `deinit` can cancel them — a `CancellationBox` because a
    /// `@MainActor` class cannot read its own stored properties from `deinit` in Swift 6.0.
    private let inputObservation = CancellationBox()
    private let snapshotObservation = CancellationBox()

    public init(
        repository: any SmokingRepository,
        editEvent: EditEvent,
        deleteEvent: DeleteEvent,
        clock: any SalusClock
    ) {
        self.editEvent = editEvent
        self.deleteEvent = deleteEvent
        self.clock = clock

        // The snapshot ticks every minute, which is also what keeps the journey's day count fresh.
        let inputs = repository.observeInput()
        inputObservation.replace(with: Task { [weak self] in
            for await input in inputs {
                guard let self, !Task.isCancelled else { return }
                latestInput = input
                refresh()
            }
        })
        let snapshots = repository.observeSnapshot()
        snapshotObservation.replace(with: Task { [weak self] in
            for await snapshot in snapshots {
                guard let self, !Task.isCancelled else { return }
                latestSnapshot = snapshot
                refresh()
            }
        })
    }

    deinit {
        inputObservation.cancel()
        snapshotObservation.cancel()
    }

    /// Drains the queued effects in order, leaving the queue empty.
    @discardableResult
    public func consumeEffects() -> [SmokingHistoryEffect] {
        let drained = pendingEffects
        pendingEffects.removeAll()
        return drained
    }

    /// One case per event, as in the Kotlin `when`; the arms are one-liners.
    public func onEvent(_ event: SmokingHistoryEvent) {
        switch event {
        case let .rowTapped(eventId):
            if state.days.contains(where: { day in day.rows.contains { $0.id == eventId } }) {
                state.editingId = eventId
            }

        // Not while a write is in flight: the sheet closes with it.
        case .editDismissed:
            if !state.writing {
                state.editingId = nil
                state.deleteConfirm = false
            }

        case let .editSaved(edit):
            save(edit)

        case .deleteTapped:
            if state.editingId != nil {
                state.deleteConfirm = true
            }

        case .deleteDismissed:
            if !state.writing {
                state.deleteConfirm = false
            }

        case .deleteConfirmed:
            delete()
        }
    }

    private func save(_ edit: EventEdit) {
        guard !state.writing, state.editingId == edit.eventId else { return }
        // An entry in the future would sit above "today" in the log and count toward a day that
        // has not happened; the use case does not refuse it, so the screen's rule is kept here.
        guard edit.atMs <= clock.nowEpochMilliseconds() else {
            pendingEffects.append(.showError(.future))
            return
        }
        state.writing = true
        Task { [weak self, editEvent] in
            do {
                try await editEvent(
                    eventId: edit.eventId,
                    atMs: edit.atMs,
                    units: edit.units.map(Int64.init),
                    trigger: edit.trigger,
                    intensity: edit.intensity
                )
                self?.written()
            } catch {
                self?.failed(error, keepConfirm: true)
            }
        }
    }

    private func delete() {
        guard let id = state.editingId, !state.writing, state.deleteConfirm else { return }
        state.writing = true
        Task { [weak self, deleteEvent] in
            do {
                // By id: the entry the person is looking at, never "the latest one".
                try await deleteEvent(eventId: id)
                self?.written()
            } catch {
                self?.failed(error, keepConfirm: false)
            }
        }
    }

    private func written() {
        state.writing = false
        state.editingId = nil
        state.deleteConfirm = false
    }

    /// A refused write: the state is as it was, only the busy flag drops (and a delete's dialog,
    /// whose question is answered), and the person is told.
    private func failed(_ error: any Error, keepConfirm: Bool) {
        state.writing = false
        if !keepConfirm {
            state.deleteConfirm = false
        }
        pendingEffects.append(.showError(error.historyError))
    }

    // MARK: Rows

    private func refresh() {
        guard let input = latestInput, let snapshot = latestSnapshot else { return }
        let nowMs = clock.nowEpochMilliseconds()
        let zone = clock.timeZone()
        var next = state
        next.loaded = true
        next.journeyDays = journeyDays(of: input, nowMs: nowMs)
        next.currencyCode = input.plan?.currencyCode ?? ""
        next.attempts = attemptCards(input: input, snapshot: snapshot)
        next.days = dayGroups(of: input.events)
        next.todayEpochDay = localEpochDay(of: nowMs, in: zone)
        next.zoneId = zone.identifier
        // The editor follows its entry: gone (deleted elsewhere) means closed.
        if next.editing == nil {
            next.editingId = nil
            next.deleteConfirm = false
        }
        state = next
    }

    private func dayGroups(of events: [SmokingEvent]) -> [DayGroupUi] {
        let newestFirst = events.sorted {
            $0.occurredAtMs != $1.occurredAtMs ? $0.occurredAtMs > $1.occurredAtMs : $0.id > $1.id
        }
        return Dictionary(grouping: newestFirst, by: \.epochDay)
            .map { epochDay, events in DayGroupUi(epochDay: epochDay, rows: events.map(\.row)) }
            .sorted { $0.epochDay > $1.epochDay }
    }

    /// Whole days from the earliest start of anything tracked: the plan or the first attempt,
    /// whichever came first.
    private func journeyDays(of input: SmokingInput, nowMs: Int64) -> Int64 {
        let starts = input.attempts.map(\.startedAtMs) + [input.plan?.createdAtMs].compactMap(\.self)
        guard let start = starts.min() else { return 0 }
        return max(0, (nowMs - start) / Self.dayMs)
    }

    private func attemptCards(input: SmokingInput, snapshot: SmokingSnapshot) -> [AttemptCardUi] {
        if case let .quit(quit) = snapshot {
            return quit.attempts.map { summary in
                AttemptCardUi(
                    id: summary.id,
                    ordinal: summary.ordinal,
                    startedAtMs: summary.startedAtMs,
                    endedAtMs: summary.endedAtMs,
                    durationMs: summary.durationMs,
                    slipCount: summary.slipCount,
                    isLongest: summary.isLongest,
                    savedMinor: summary.savedMinor,
                    cravingsBeaten: summary.cravingsBeaten,
                    tzId: input.attempts.first { $0.id == summary.id }?.tzId ?? ""
                )
            }
        }
        return storedAttemptCards(input)
    }

    /// The attempts of a plan whose snapshot has none (REDUCE). Same readings as contract §3.15: a
    /// closed attempt lasts `end − start`, the longest is the max and the earliest wins a tie; the
    /// slips are the entries linked to it.
    private func storedAttemptCards(_ input: SmokingInput) -> [AttemptCardUi] {
        let ordered = input.attempts.sorted { $0.startedAtMs < $1.startedAtMs }
        let durations = ordered.map { max(0, ($0.endedAtMs ?? $0.startedAtMs) - $0.startedAtMs) }
        // `firstIndex` is the first match: the earliest attempt wins a tie.
        let longest = durations.max().flatMap { durations.firstIndex(of: $0) }
        return ordered.enumerated().map { index, attempt in
            AttemptCardUi(
                id: attempt.id,
                ordinal: index + 1,
                startedAtMs: attempt.startedAtMs,
                endedAtMs: attempt.endedAtMs,
                durationMs: durations[index],
                slipCount: input.events
                    .filter { $0.attemptId == attempt.id && $0.type == .smoked && ($0.units ?? 0) > 0 }
                    .count,
                isLongest: index == longest,
                savedMinor: nil,
                cravingsBeaten: nil,
                tzId: attempt.tzId
            )
        }
    }

    private static let dayMs: Int64 = 24 * 60 * 60 * 1000
}

extension SmokingEvent {
    fileprivate var row: EventRowUi {
        EventRowUi(
            id: id,
            type: type,
            atMs: occurredAtMs,
            tzId: tzId,
            units: units.map(Int.init),
            trigger: trigger,
            intensity: intensity
        )
    }
}

extension Error {
    /// `Throwable.messageRes()`: the three refusals a history write can meet.
    fileprivate var historyError: SmokingHistoryError {
        switch self as? SmokingError {
        case .futureQuitDate: .future
        case .invalidInput, .notSetUp: .invalid
        case nil: .generic
        }
    }
}
