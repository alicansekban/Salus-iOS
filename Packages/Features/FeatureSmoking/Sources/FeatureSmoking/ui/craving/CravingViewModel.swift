// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/craving/
// CravingViewModel.kt`.
//
// `MutableStateFlow` + `update { it.copy(…) }` becomes an `@Observable` `state` mutated in place;
// `viewModelScope.launch` becomes a `Task` inside a `@MainActor` type; the buffered effect `Channel`
// becomes `pendingEffects` + `consumeEffects()` (`SmokingMainViewModel`'s shape).
//
// Not ported: the `SavedStateHandle`. Android keeps the start instant and the logged craving there,
// so a ViewModel rebuilt after process death carries on from the original start. iOS keeps nothing
// across a termination (plan Task 12): the rebuilt ViewModel begins afresh and writes nothing, and
// the person is back on the screen they opened it from, not on a half-finished flow. Backgrounding
// is a different thing and is kept — see ``refreshClock()``.

import Foundation
import Observation
import SalusCommon
import SalusSmoking

/// The craving flow. The remaining time is not counted down: it is `5:00 - (now - startedAt)`, and
/// `startedAt` is read once from the clock when the flow opens. So it keeps running while the app
/// is in the background; a person who comes back after more than five minutes finds the timer
/// done. ``runClock()`` only re-reads the clock.
///
/// A craving is written only by "Geçti" (contract §6). Closing and the timer running out write
/// nothing. Every write sets ``CravingUiState/writing`` before it starts, so a second tap while the
/// first is in flight does nothing, and "close" is ignored until it ends.
@MainActor
@Observable
public final class CravingViewModel {
    public private(set) var state: CravingUiState

    /// Errors waiting for the Route to show them, oldest first.
    public private(set) var pendingEffects: [CravingEffect] = []

    private let clock: any SalusClock
    private let logCravingResisted: LogCravingResisted
    private let logSmoked: LogSmoked
    private let resolveSlip: ResolveSlip
    private let editEvent: EditEvent
    /// Closes the cover, bound to the presenter's `dismiss()` rather than to `navigator.pop()`: a
    /// pop is applied to whatever stack is on top when it arrives, so a write that finishes after a
    /// notification tap already closed the cover and pushed its screen would pop that screen.
    /// Dismissing a cover that is gone is a no-op.
    private let closeCover: @MainActor () -> Void

    /// The instant the flow began. A `let`: the timer is a function of it and the clock, nothing else.
    private let startedAtMs: Int64

    /// The entry the trigger sheet is about. `EditEvent` rewrites the whole entry, so the time and
    /// the units it was logged with have to come back with the trigger.
    private var lastWrite: LoggedEntry?

    /// The count the latest snapshot saw, before this craving is written: the active attempt's in
    /// QUIT (the Main tile counts the attempt, so "n. krizi atlattın" must agree with it), all-time
    /// in REDUCE, which has no attempt.
    private var cravingsBeaten: Int?

    /// Whether the flow has asked to be left.
    private var left = false

    /// The snapshot observation, held so `deinit` can cancel it — a `CancellationBox` because a
    /// `@MainActor` class cannot read its own stored properties from `deinit` in Swift 6.0.
    private let observation = CancellationBox()

    public init(
        repository: any SmokingRepository,
        clock: any SalusClock,
        logCravingResisted: LogCravingResisted,
        logSmoked: LogSmoked,
        resolveSlip: ResolveSlip,
        editEvent: EditEvent,
        closeCover: @escaping @MainActor () -> Void
    ) {
        self.clock = clock
        self.logCravingResisted = logCravingResisted
        self.logSmoked = logSmoked
        self.resolveSlip = resolveSlip
        self.editEvent = editEvent
        self.closeCover = closeCover
        startedAtMs = clock.nowEpochMilliseconds()
        state = CravingUiState()

        let snapshots = repository.observeSnapshot()
        observation.replace(with: Task { [weak self] in
            for await snapshot in snapshots {
                guard let self, !Task.isCancelled else { return }
                apply(snapshot)
            }
        })
    }

    deinit {
        observation.cancel()
    }

    /// Drains the queued effects in order, leaving the queue empty.
    @discardableResult
    public func consumeEffects() -> [CravingEffect] {
        let drained = pendingEffects
        pendingEffects.removeAll()
        return drained
    }

    public func onEvent(_ event: CravingEvent) {
        switch event {
        case .passedTapped:
            passed()

        case .continueTapped:
            continueToTrigger()

        case .smokedTapped:
            smoked()

        case let .slipConfirmed(units, restart):
            confirmSlip(units: units, restart: restart)

        case .slipDismissed:
            if state.sheet == .slip, !state.writing {
                state.sheet = nil
            }

        case let .triggerSaved(trigger, intensity):
            saveTrigger(trigger: trigger, intensity: intensity)

        case .triggerSkipped:
            if case .trigger = state.sheet, !state.writing {
                leave()
            }

        // Not while a write is in flight: a vanished screen would leave its sheet and its result
        // half way.
        case .closeTapped:
            if !state.writing {
                leave()
            }
        }
    }

    /// Reads the clock into the state. The first read after the app comes back from the background
    /// is what carries the time spent away.
    public func refreshClock() {
        state.elapsedMs = elapsedMs()
    }

    /// Re-reads the clock until the five minutes are up, on the second boundary of the flow so the
    /// breath phases (whole seconds) change on time. The Route runs this only while the scene is
    /// active; cancelling it ends the loop.
    public func runClock() async {
        while !Task.isCancelled {
            refreshClock()
            let elapsed = state.elapsedMs
            if elapsed >= cravingDurationMs {
                return
            }
            do {
                try await Task.sleep(for: .milliseconds(Self.secondMs - elapsed % Self.secondMs))
            } catch {
                return
            }
        }
    }

    // MARK: Snapshot

    private func apply(_ snapshot: SmokingSnapshot) {
        switch snapshot {
        case let .quit(quit):
            cravingsBeaten = quit.cravingsBeaten
        case let .reduce(reduce):
            cravingsBeaten = reduce.cravingsBeatenAllTime
        case .notSetUp:
            cravingsBeaten = nil
        }
        state.mode = Self.mode(of: snapshot)
        state.lines = Self.lines(of: snapshot)
        state.reason = Self.reason(of: snapshot)
    }

    // MARK: Writes

    private func passed() {
        guard !state.writing, !state.logged else { return }
        state.writing = true
        let atMs = clock.nowEpochMilliseconds()
        // This craving is one more than the snapshot has seen: it is not written yet.
        let count = cravingsBeaten.map { $0 + 1 }
        Task { [weak self, logCravingResisted] in
            do {
                let eventId = try await logCravingResisted(atMs: atMs)
                self?.passedWritten(LoggedEntry(eventId: eventId, atMs: atMs, units: nil), count: count)
            } catch {
                self?.failed()
            }
        }
    }

    private func passedWritten(_ entry: LoggedEntry, count: Int?) {
        lastWrite = entry
        state.writing = false
        state.logged = true
        state.loggedCount = count
    }

    private func continueToTrigger() {
        guard state.logged, !state.writing else { return }
        guard let entry = lastWrite else {
            leave()
            return
        }
        state.sheet = .trigger(eventId: entry.eventId)
    }

    private func smoked() {
        guard !state.writing, !state.logged, state.sheet == nil else { return }
        switch state.mode {
        // Nothing is written until the slip sheet is confirmed: the sheet decides restart or not.
        case .quit:
            state.sheet = .slip

        case .reduce:
            state.writing = true
            let atMs = clock.nowEpochMilliseconds()
            Task { [weak self, logSmoked] in
                do {
                    _ = try await logSmoked(units: 1, atMs: atMs)
                    self?.state.writing = false
                    self?.leave()
                } catch {
                    self?.failed()
                }
            }

        // The snapshot has not said which plan this is yet.
        case nil:
            break
        }
    }

    private func confirmSlip(units: Int, restart: Bool) {
        guard !state.writing, state.sheet == .slip else { return }
        state.writing = true
        let atMs = clock.nowEpochMilliseconds()
        Task { [weak self, resolveSlip] in
            do {
                let eventId = try await resolveSlip(units: Int64(units), atMs: atMs, restart: restart)
                self?.slipWritten(LoggedEntry(eventId: eventId, atMs: atMs, units: units))
            } catch {
                self?.failed()
            }
        }
    }

    private func slipWritten(_ entry: LoggedEntry) {
        lastWrite = entry
        state.writing = false
        state.sheet = .trigger(eventId: entry.eventId)
    }

    private func saveTrigger(trigger: CravingTrigger?, intensity: Int?) {
        guard !state.writing, case let .trigger(eventId) = state.sheet else { return }
        let entry = lastWrite.flatMap { $0.eventId == eventId ? $0 : nil }
        // Nothing chosen, or an entry this screen did not write: there is nothing to add to it.
        guard let entry, trigger != nil || intensity != nil else {
            leave()
            return
        }
        state.writing = true
        Task { [weak self, editEvent] in
            do {
                try await editEvent(
                    eventId: entry.eventId,
                    atMs: entry.atMs,
                    units: entry.units.map(Int64.init),
                    trigger: trigger,
                    intensity: intensity
                )
                self?.state.writing = false
                self?.leave()
            } catch {
                self?.failed()
            }
        }
    }

    /// Once. A second tap on the close button, or a trigger sheet and the close button racing, must
    /// not close twice; and a close after the cover is already gone (see ``closeCover``) touches
    /// nothing.
    private func leave() {
        guard !left else { return }
        left = true
        state.sheet = nil
        closeCover()
    }

    /// A refused write: the state is as it was, only the busy flag drops, and the person is told.
    private func failed() {
        state.writing = false
        pendingEffects.append(.showError)
    }

    /// Below zero (a device clock set back past the start) reads as the beginning.
    private func elapsedMs() -> Int64 {
        max(0, clock.nowEpochMilliseconds() - startedAtMs)
    }

    private struct LoggedEntry {
        let eventId: String
        let atMs: Int64
        let units: Int?
    }

    private static let secondMs: Int64 = 1000
    private static let dayMs: Int64 = 86_400_000

    private static func mode(of snapshot: SmokingSnapshot) -> CravingMode? {
        switch snapshot {
        case .quit: .quit
        case .reduce: .reduce
        case .notSetUp: nil
        }
    }

    private static func reason(of snapshot: SmokingSnapshot) -> String? {
        let plan: SmokingPlan? = switch snapshot {
        case let .quit(quit): quit.plan
        case let .reduce(reduce): reduce.plan
        case .notSetUp: nil
        }
        let trimmed = plan?.reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Days, savings and the next stage, in that order, then the breath line that is always there.
    private static func lines(of snapshot: SmokingSnapshot) -> [CravingLine] {
        var lines: [CravingLine] = []
        switch snapshot {
        case let .quit(quit):
            let days = Int(quit.attemptElapsedMs / dayMs)
            if days >= 1 {
                lines.append(.smokeFreeDays(days))
            }
            if quit.savedMinor > 0 {
                lines.append(.saved(minor: quit.savedMinor, currencyCode: quit.plan.currencyCode))
            }
            if let stage = quit.nextStage, StageCopy.title(of: stage.stageId) != nil {
                lines.append(.nextStage(stageId: stage.stageId))
            }

        case let .reduce(reduce):
            if reduce.savedSinceSetupMinor > 0 {
                lines.append(.saved(minor: reduce.savedSinceSetupMinor, currencyCode: reduce.plan.currencyCode))
            }

        case .notSetUp:
            break
        }
        lines.append(.focus)
        return lines
    }
}
