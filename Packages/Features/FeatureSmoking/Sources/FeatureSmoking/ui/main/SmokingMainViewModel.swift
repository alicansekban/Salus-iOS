// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// SmokingMainViewModel.kt`.
//
// `MutableStateFlow` + `update { it.copy(…) }` becomes an `@Observable` `state` mutated in place;
// `viewModelScope.launch` becomes a `Task` inside a `@MainActor` type; the buffered effect `Channel`
// becomes `pendingEffects` + `consumeEffects()` (`SmokingSetupViewModel`'s shape).
//
// REDUCE writes (+1, its undo) do not run on `viewModelScope` in Kotlin but on an app-wide
// `writeScope`, because the shell's snackbar outlives this screen. Here an unstructured `Task` is
// already independent of the ViewModel's lifetime, so the same rule is: the write and the undo hold
// the use cases and the shell's snackbar controller, never `self`, and a ViewModel that is gone
// changes nothing about them.
//
// Not ported: `runClock`. The counters between two snapshots are moved by the view's
// `TimelineView` (see `SmokingMainTime.swift`), so the ViewModel holds no ticker and no
// `liveNowMs`.

import Foundation
import Observation
import SalusCommon
import SalusNavigation
import SalusPremium
import SalusSmoking
import SalusUI

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
    private let logSmoked: LogSmoked
    private let deleteEvent: DeleteEvent
    private let logNoneToday: LogNoneToday
    private let switchMode: SwitchMode
    private let saveSavingsGoal: SaveSavingsGoal
    private let markGoalAchieved: MarkGoalAchieved
    private let updateSavingsGoal: UpdateSavingsGoal
    private let paywallController: PaywallController
    private let snackbar: SalusSnackbarController
    private let navigator: Navigator

    /// The slip the trigger sheet is about. `EditEvent` rewrites the whole entry, so the time and
    /// the units it was logged with have to come back with the trigger; the sheet itself only
    /// names the event.
    private var lastSlip: LoggedSlip?

    /// The goal a stamp is already on its way for. Snapshots arrive every minute and on every
    /// write, and the stamp's own write has not landed in the next one yet, so without this a
    /// re-emission would start a second stamp for the same goal.
    private var stampingGoalId: String?

    /// The snapshot and entitlement observations, held so `deinit` can cancel them — a
    /// `CancellationBox` each because a `@MainActor` class cannot read its own stored properties
    /// from `deinit` in Swift 6.0.
    private let observation = CancellationBox()
    private let entitlementObservation = CancellationBox()

    public init(
        repository: any SmokingRepository,
        clock: any SalusClock,
        resolveSlip: ResolveSlip,
        editEvent: EditEvent,
        logSmoked: LogSmoked,
        deleteEvent: DeleteEvent,
        logNoneToday: LogNoneToday,
        switchMode: SwitchMode,
        saveSavingsGoal: SaveSavingsGoal,
        markGoalAchieved: MarkGoalAchieved,
        updateSavingsGoal: UpdateSavingsGoal,
        premiumRepository: any PremiumRepository,
        paywallController: PaywallController,
        snackbar: SalusSnackbarController,
        navigator: Navigator
    ) {
        self.clock = clock
        self.resolveSlip = resolveSlip
        self.editEvent = editEvent
        self.logSmoked = logSmoked
        self.deleteEvent = deleteEvent
        self.logNoneToday = logNoneToday
        self.switchMode = switchMode
        self.saveSavingsGoal = saveSavingsGoal
        self.markGoalAchieved = markGoalAchieved
        self.updateSavingsGoal = updateSavingsGoal
        self.paywallController = paywallController
        self.snackbar = snackbar
        self.navigator = navigator

        let snapshots = repository.observeSnapshot()
        observation.replace(with: Task { [weak self] in
            for await snapshot in snapshots {
                guard let self, !Task.isCancelled else { return }
                state.snapshot = snapshot
                stampGoalIfReached()
            }
        })
        let statuses = premiumRepository.status
        entitlementObservation.replace(with: Task { [weak self] in
            for await status in statuses {
                guard let self, !Task.isCancelled else { return }
                entitlementChanged(isPremium: status.isEntitled)
            }
        })
    }

    deinit {
        observation.cancel()
        entitlementObservation.cancel()
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
            openNextStage()

        case .historyTapped:
            navigator.navigate(SmokingHistoryKey())

        case .settingsTapped:
            navigator.navigate(SmokingSettingsKey())

        case .goalDismissed, .goalSaved, .goalTapped, .insightsTapped:
            onPremiumEvent(event)

        case .noneToday, .plusOne, .quitDateConfirmed, .quitDateDismissed, .readyToQuit, .timelinePreviewTapped,
             .undoPlusOne:
            onReduceEvent(event)
        }
    }

    private func openNextStage() {
        if case let .quit(quit) = state.snapshot, let stage = quit.nextStage {
            navigator.navigate(SmokingTimelineKey(highlightStageId: stage.stageId))
        }
    }

    /// The REDUCE half of ``onEvent(_:)``, split off to keep each `switch` readable.
    private func onReduceEvent(_ event: SmokingMainEvent) {
        switch event {
        case .plusOne:
            plusOne()

        case let .undoPlusOne(eventId):
            Self.undo(eventId, deleteEvent: deleteEvent, snackbar: snackbar)

        case .noneToday:
            noneToday()

        case .readyToQuit:
            if case .reduce = state.snapshot, state.sheet == nil {
                state.sheet = .quitDate
            }

        case let .quitDateConfirmed(quitAtMs):
            confirmQuitDate(quitAtMs)

        case .quitDateDismissed:
            if state.sheet == .quitDate, !state.writing {
                state.sheet = nil
            }

        case .timelinePreviewTapped:
            navigator.navigate(SmokingTimelineKey())

        // The cases `onEvent` never sends here.
        default:
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

    // MARK: REDUCE writes

    /// The entry's id travels in the snackbar's action so the undo removes that row, whichever day
    /// it is by then: a snackbar can outlive midnight, and "today's last entry" would then be
    /// someone else's. A failure goes to the shell's snackbar rather than to ``pendingEffects``,
    /// which nobody drains once the screen is gone.
    private func plusOne() {
        guard !state.writing, case .reduce = state.snapshot else { return }
        state.writing = true
        let atMs = clock.nowEpochMilliseconds()
        Task { [weak self, logSmoked, deleteEvent, snackbar] in
            do {
                let eventId = try await logSmoked(units: 1, atMs: atMs)
                self?.state.writing = false
                snackbar.show(Self.undoOffer(eventId, deleteEvent: deleteEvent, snackbar: snackbar))
            } catch {
                self?.state.writing = false
                snackbar.show(SnackbarRequest(message: SmokingStrings.errorGeneric))
            }
        }
    }

    /// "1 adet eklendi · Geri al". An explicit window: with an action label the controller's own
    /// default is "never", which would hold up every snackbar queued behind this one.
    private static func undoOffer(
        _ eventId: String,
        deleteEvent: DeleteEvent,
        snackbar: SalusSnackbarController
    ) -> SnackbarRequest {
        SnackbarRequest(
            message: SmokingStrings.reduceAdded,
            actionLabel: SalusUIStrings.undo,
            onAction: { undo(eventId, deleteEvent: deleteEvent, snackbar: snackbar) },
            duration: .long
        )
    }

    /// Not behind the busy flag: deleting by id is idempotent, and an undo must never be swallowed
    /// because some other write happens to be in flight.
    private static func undo(_ eventId: String, deleteEvent: DeleteEvent, snackbar: SalusSnackbarController) {
        Task {
            do {
                try await deleteEvent(eventId: eventId)
            } catch {
                snackbar.show(SnackbarRequest(message: SmokingStrings.errorGeneric))
            }
        }
    }

    private func noneToday() {
        guard !state.writing, case .reduce = state.snapshot else { return }
        state.writing = true
        Task { [weak self, logNoneToday] in
            do {
                try await logNoneToday()
                self?.state.writing = false
            } catch {
                self?.failed()
            }
        }
    }

    /// "Bırakmaya hazırım" ends here. A refusal (a start before the last closed attempt ended, or a
    /// future instant) leaves the plan and the open sheet as they were and says why.
    private func confirmQuitDate(_ quitAtMs: Int64) {
        guard !state.writing, state.sheet == .quitDate else { return }
        state.writing = true
        Task { [weak self, switchMode] in
            do {
                try await switchMode(to: .quit, quitAtMs: quitAtMs)
                self?.state.writing = false
                self?.state.sheet = nil
            } catch SmokingError.invalidInput {
                self?.failed(.quitOverlap)
            } catch SmokingError.futureQuitDate {
                self?.failed(.quitFuture)
            } catch {
                self?.failed()
            }
        }
    }

    /// A refused write: the state is as it was, only the busy flag drops, and the person is told.
    private func failed(_ error: SmokingMainError = .generic) {
        state.writing = false
        pendingEffects.append(.showError(error))
    }

    private struct LoggedSlip {
        let eventId: String
        let atMs: Int64
        let units: Int
    }

    private static let cravingSource = "main"
    private static let defaultSlipUnits = 1
}

// MARK: - Premium: savings goal and insights

/// An extension in this file, not part of the class body: it reaches the same private state, and the
/// class stays inside SwiftLint's `type_body_length`.
extension SmokingMainViewModel {
    /// The goal card's and the teaser's half of ``onEvent(_:)``.
    private func onPremiumEvent(_ event: SmokingMainEvent) {
        switch event {
        case .goalTapped:
            goalTapped()

        case let .goalSaved(title, targetMinor):
            saveGoal(title: title, targetMinor: targetMinor)

        case .goalDismissed:
            if case .goal = state.sheet, !state.writing {
                state.sheet = nil
            }

        case .insightsTapped:
            insightsTapped()

        // The cases `onEvent` never sends here.
        default:
            break
        }
    }

    /// A goal sheet over a card that has just re-locked would save a goal nobody can see; closing
    /// it also keeps the sheet from outliving the entitlement. A write in flight keeps its sheet,
    /// as every other dismissal does.
    private func entitlementChanged(isPremium: Bool) {
        state.isPremium = isPremium
        if !isPremium, case .goal = state.sheet, !state.writing {
            state.sheet = nil
        }
        stampGoalIfReached()
    }

    private func goalTapped() {
        guard state.isPremium else {
            paywallController.show(.smokingGoal)
            return
        }
        guard state.sheet == nil, state.snapshot?.hasPlan == true else { return }
        // Only a goal still being saved for is offered back for editing; a reached one starts blank.
        let active = state.snapshot?.goalProgress.flatMap { $0.reached ? nil : $0.goal }
        state.sheet = .goal(title: active?.title ?? "", targetMinor: active?.targetMinor, editingGoalId: active?.id)
    }

    /// A refusal (the use case rejects a blank title or a non-positive target; a store failure)
    /// leaves the sheet open as it was and says so. Editing a goal still being saved for keeps its
    /// progress (contract §8.17, which supersedes plan ruling D4's restart); only a first goal or
    /// one after a reached goal is created new and counts from now.
    private func saveGoal(title: String, targetMinor: Int64) {
        guard !state.writing, case let .goal(_, _, editingGoalId) = state.sheet, state.isPremium else { return }
        state.writing = true
        Task { [weak self, saveSavingsGoal, updateSavingsGoal] in
            do {
                if let editingGoalId {
                    try await updateSavingsGoal(goalId: editingGoalId, title: title, targetMinor: targetMinor)
                } else {
                    try await saveSavingsGoal(title: title, targetMinor: targetMinor)
                }
                self?.goalWritten()
            } catch {
                self?.failed()
            }
        }
    }

    private func goalWritten() {
        state.writing = false
        state.sheet = nil
    }

    /// The teaser opens Trends for a premium account. That screen belongs to another feature, so
    /// the Route asks the shell for it on the effect; a free account meets the paywall instead.
    private func insightsTapped() {
        if state.isPremium {
            pendingEffects.append(.openTrends)
        } else {
            paywallController.show(.smokingInsights)
        }
    }

    /// Stamps a goal that has reached its target, once. Only while the card is unlocked: a lapsed
    /// account's goal is kept as it is and is stamped when the card comes back. A failed stamp is
    /// not reported (nobody asked for it) and is simply tried again on the next emission.
    private func stampGoalIfReached() {
        guard let progress = state.snapshot?.goalProgress else { return }
        let goal = progress.goal
        guard state.isPremium, progress.reached, goal.achievedAtMs == nil, stampingGoalId != goal.id else { return }
        stampingGoalId = goal.id
        Task { [weak self, markGoalAchieved] in
            do {
                try await markGoalAchieved(goalId: goal.id)
            } catch {
                self?.stampingGoalId = nil
            }
        }
    }
}
