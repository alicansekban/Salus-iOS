// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/settings/
// SmokingSettingsViewModel.kt`.
//
// `MutableStateFlow` + `update { it.copy(…) }` becomes an `@Observable` `state` mutated in place;
// `viewModelScope.launch` becomes a `Task` inside a `@MainActor` type; the buffered effect `Channel`
// becomes `pendingEffects` + `consumeEffects()` (`SmokingMainViewModel`'s shape); `combine(…)` is
// spelled as in `SmokingHistoryViewModel`.
//
// One platform difference: `ReminderEnvironment.areNotificationsEnabled()` is synchronous on
// Android; the iOS authorization is an `async` question (`notificationsAuthorized()`), so the
// switch's follow-up is awaited after the write has landed.

import Foundation
import Observation
import SalusCommon
import SalusNavigation
import SalusReminder
import SalusSmoking

/// The smoking settings. Every row is one use-case call. A write that is refused leaves the state as
/// it was, drops the busy flag and queues an error effect; a sheet that was open stays open so the
/// value can be corrected, a confirmation that was open closes.
///
/// Two things change what the figures mean, so they ask first: a currency (relabelled, never
/// converted, plan ruling D5) and a quit date (slips before it detach from the attempt).
/// Notification switches are saved either way; turning one on while the system would not show the
/// notification also opens the reminder-readiness screen, the way the medication editor steers.
@MainActor
@Observable
public final class SmokingSettingsViewModel {
    public private(set) var state = SmokingSettingsUiState()

    /// Errors and hops waiting for the Route, oldest first.
    public private(set) var pendingEffects: [SmokingSettingsEffect] = []

    private let updatePrice: UpdatePrice
    private let updateCurrency: UpdateCurrency
    private let updatePlanFields: UpdatePlanFields
    private let editQuitDate: EditQuitDate
    private let switchMode: SwitchMode
    private let resetSmoking: ResetSmoking
    private let environment: any ReminderEnvironment
    private let clock: any SalusClock
    private let navigator: Navigator

    private var latestInput: SmokingInput?
    private var latestSnapshot: SmokingSnapshot?

    /// The two observations, held so `deinit` can cancel them — a `CancellationBox` because a
    /// `@MainActor` class cannot read its own stored properties from `deinit` in Swift 6.0.
    private let inputObservation = CancellationBox()
    private let snapshotObservation = CancellationBox()

    public init(
        repository: any SmokingRepository,
        updatePrice: UpdatePrice,
        updateCurrency: UpdateCurrency,
        updatePlanFields: UpdatePlanFields,
        editQuitDate: EditQuitDate,
        switchMode: SwitchMode,
        resetSmoking: ResetSmoking,
        environment: any ReminderEnvironment,
        clock: any SalusClock,
        navigator: Navigator
    ) {
        self.updatePrice = updatePrice
        self.updateCurrency = updateCurrency
        self.updatePlanFields = updatePlanFields
        self.editQuitDate = editQuitDate
        self.switchMode = switchMode
        self.resetSmoking = resetSmoking
        self.environment = environment
        self.clock = clock
        self.navigator = navigator

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
    public func consumeEffects() -> [SmokingSettingsEffect] {
        let drained = pendingEffects
        pendingEffects.removeAll()
        return drained
    }

    /// One case per event, as in the Kotlin `when`, in three groups: the rows that open an editor,
    /// the editors' own results, and the confirmations and switches.
    public func onEvent(_ event: SmokingSettingsEvent) {
        switch event {
        case .currencyTapped, .limitTapped, .priceTapped, .quitDateTapped, .reasonTapped, .resetTapped,
             .sheetDismissed, .switchModeTapped:
            onRowEvent(event)

        case .currencyPicked, .limitSaved, .priceSaved, .quitDatePicked, .reasonSaved, .switchToQuitConfirmed,
             .switchToReduceConfirmed:
            onSheetEvent(event)

        case .confirmAccepted, .confirmDismissed, .eveningToggled, .notificationsToggled:
            onConfirmOrSwitchEvent(event)
        }
    }

    private func onRowEvent(_ event: SmokingSettingsEvent) {
        switch event {
        case .priceTapped: open(.price)

        case .currencyTapped: open(.currency)

        case .limitTapped: open(.limit)

        case .reasonTapped: open(.reason)

        case .quitDateTapped:
            if let quitAtMs = state.quitAtMs {
                open(.quitDate(initialMs: quitAtMs))
            }

        case .switchModeTapped: switchModeTapped()

        case .resetTapped:
            if !state.writing {
                state.confirm = .reset
            }

        // Not while a write is in flight: the sheet closes with it.
        case .sheetDismissed:
            if !state.writing {
                state.sheet = .none
            }

        default: break
        }
    }

    private func onSheetEvent(_ event: SmokingSettingsEvent) {
        switch event {
        case let .priceSaved(unitCostMinor):
            write(closeSheet: true) { [updatePrice] in try await updatePrice(unitCostMinor: unitCostMinor) }

        case let .limitSaved(limit):
            var fields = currentFields
            fields.dailyLimit = limit
            write(closeSheet: true, block: planWrite(fields))

        case let .reasonSaved(text):
            var fields = currentFields
            fields.reason = text
            write(closeSheet: true, block: planWrite(fields))

        case let .currencyPicked(code): currencyPicked(code)

        case let .quitDatePicked(atMs):
            if !state.writing {
                state.sheet = .none
                state.confirm = .quitDate(atMs)
            }

        case let .switchToReduceConfirmed(limit):
            write(closeSheet: true) { [switchMode] in try await switchMode(to: .reduce, dailyLimit: Int64(limit)) }

        case let .switchToQuitConfirmed(quitAtMs):
            write(closeSheet: true) { [switchMode] in try await switchMode(to: .quit, quitAtMs: quitAtMs) }

        default: break
        }
    }

    private func onConfirmOrSwitchEvent(_ event: SmokingSettingsEvent) {
        switch event {
        case .confirmAccepted: accept()

        case .confirmDismissed:
            if !state.writing {
                state.confirm = nil
            }

        case let .notificationsToggled(enabled):
            var fields = currentFields
            fields.notificationsEnabled = enabled
            toggle(enabled, fields)

        case let .eveningToggled(enabled):
            var fields = currentFields
            fields.eveningReminderEnabled = enabled
            toggle(enabled, fields)

        default: break
        }
    }

    private func open(_ sheet: SettingsSheet) {
        if !state.writing, state.mode != .none {
            state.sheet = sheet
        }
    }

    private func switchModeTapped() {
        switch state.mode {
        case .quit:
            state
                .sheet =
                .switchToReduce(suggestedLimit: suggestedDailyLimit(baselineUnitsPerDay: state.baselineUnitsPerDay))

        case .reduce:
            state.sheet = .switchToQuit(initialMs: clock.nowEpochMilliseconds())

        case .none:
            break
        }
    }

    private func currencyPicked(_ code: String) {
        guard !state.writing else { return }
        if code == state.currencyCode {
            state.sheet = .none
        } else {
            state.sheet = .none
            state.confirm = .currency(code)
        }
    }

    private func accept() {
        guard let confirm = state.confirm, !state.writing else { return }
        switch confirm {
        case let .currency(code):
            write(closeConfirm: true) { [updateCurrency] in try await updateCurrency(code: code) }

        case let .quitDate(atMs):
            write(closeConfirm: true) { [editQuitDate] in try await editQuitDate(newStartMs: atMs) }

        case .reset:
            write(
                closeConfirm: true,
                onSuccess: { [navigator] in
                    // Settings, then the main screen under it: back to where smoking was opened from.
                    navigator.pop()
                    navigator.pop()
                },
                block: { [resetSmoking] in try await resetSmoking() }
            )
        }
    }

    private func toggle(_ enabled: Bool, _ fields: PlanFields) {
        write(
            onSuccess: { [weak self] in
                guard enabled, let self else { return }
                if await !environment.notificationsAuthorized() {
                    pendingEffects.append(.openReminderHealth)
                }
            },
            block: planWrite(fields)
        )
    }

    /// Runs one write behind the busy flag. `closeSheet` and `closeConfirm` close the editor that
    /// asked for it, on success only; a refusal reports itself and closes the confirmation (the
    /// question is answered) but keeps the sheet.
    private func write(
        closeSheet: Bool = false,
        closeConfirm: Bool = false,
        onSuccess: (@MainActor () async -> Void)? = nil,
        block: @escaping @Sendable () async throws -> Void
    ) {
        guard !state.writing else { return }
        state.writing = true
        Task { [weak self] in
            do {
                try await block()
                guard let self else { return }
                state.writing = false
                if closeSheet {
                    state.sheet = .none
                }
                if closeConfirm {
                    state.confirm = nil
                }
                await onSuccess?()
            } catch {
                self?.writeFailed(error, closeConfirm: closeConfirm)
            }
        }
    }

    private func writeFailed(_ error: any Error, closeConfirm: Bool) {
        // The message is read off the state the write started from: the dialog that asked is about
        // to close.
        let message = error.settingsError(in: state)
        state.writing = false
        if closeConfirm {
            state.confirm = nil
        }
        pendingEffects.append(.showError(message))
    }

    // MARK: Plan fields

    /// The plan's editable fields as they stand, so a write that changes one carries the rest
    /// through unchanged (`UpdatePlanFields` takes all four).
    private struct PlanFields: Sendable {
        var dailyLimit: Int?
        var reason: String?
        var notificationsEnabled: Bool
        var eveningReminderEnabled: Bool
    }

    private var currentFields: PlanFields {
        PlanFields(
            dailyLimit: state.dailyLimit,
            reason: state.reason,
            notificationsEnabled: state.notificationsEnabled,
            eveningReminderEnabled: state.eveningReminderEnabled
        )
    }

    private func planWrite(_ fields: PlanFields) -> @Sendable () async throws -> Void {
        { [updatePlanFields] in
            try await updatePlanFields(
                dailyLimit: fields.dailyLimit.map(Int64.init),
                reason: fields.reason,
                notificationsEnabled: fields.notificationsEnabled,
                eveningReminderEnabled: fields.eveningReminderEnabled
            )
        }
    }

    // MARK: Snapshot

    private func refresh() {
        guard let input = latestInput, let snapshot = latestSnapshot else { return }
        let today = localEpochDay(of: clock.nowEpochMilliseconds(), in: clock.timeZone())
        // Contract §3.6: the latest period that has begun, else the earliest one.
        let sorted = input.prices.sorted { $0.effectiveFromEpochDay < $1.effectiveFromEpochDay }
        let unitCost = (sorted.last { $0.effectiveFromEpochDay <= today } ?? sorted.first)?.unitCostMinor ?? 0
        state = state.withPlan(of: snapshot, unitCostMinor: unitCost, zoneId: clock.timeZone().identifier)
    }
}

extension SmokingSettingsUiState {
    fileprivate func withPlan(of snapshot: SmokingSnapshot, unitCostMinor: Int64, zoneId: String) -> Self {
        var next = self
        switch snapshot {
        case let .quit(quit):
            next.apply(quit.plan, mode: .quit, unitCostMinor: unitCostMinor, zoneId: zoneId)
            next.quitAtMs = quit.attemptStartedAtMs

        case let .reduce(reduce):
            next.apply(reduce.plan, mode: .reduce, unitCostMinor: unitCostMinor, zoneId: zoneId)
            next.quitAtMs = nil

        case .notSetUp:
            next.loaded = true
            next.mode = .none
            next.sheet = .none
            next.confirm = nil
        }
        return next
    }

    private mutating func apply(_ plan: SmokingPlan, mode: SettingsMode, unitCostMinor: Int64, zoneId: String) {
        loaded = true
        self.mode = mode
        self.zoneId = zoneId
        productType = plan.productType
        baselineUnitsPerDay = Int(plan.baselineUnitsPerDay)
        currencyCode = plan.currencyCode
        self.unitCostMinor = unitCostMinor
        dailyLimit = plan.dailyLimit.map(Int.init)
        reason = plan.reason
        notificationsEnabled = plan.notificationsEnabled
        eveningReminderEnabled = plan.eveningReminderEnabled
    }
}

extension Error {
    /// A refusal in plain words. `invalidInput` from a quit time is the attempts-never-overlap rule
    /// (contract §8.10); anywhere else it is a value the sheet should not have sent.
    fileprivate func settingsError(in state: SmokingSettingsUiState) -> SmokingSettingsError {
        switch self as? SmokingError {
        case .futureQuitDate:
            return .futureDate

        case .invalidInput:
            if case .quitDate = state.confirm {
                return .overlap
            }
            if case .switchToQuit = state.sheet {
                return .overlap
            }
            return .invalid

        case .notSetUp:
            return .invalid

        case nil:
            return .generic
        }
    }
}
