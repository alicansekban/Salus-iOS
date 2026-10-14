// Ported from `feature/smoking/src/test/kotlin/com/alicansekban/salus/feature/smoking/ui/settings/
// SmokingSettingsViewModelTest.kt`.
//
// The ViewModel is exercised over the real calculator and the real use cases; only the store is
// fake. `advanceUntilIdle()` becomes `waitUntil`, and the Turbine `effects.test { awaitItem() }`
// becomes `consumeEffects()` after the write has landed.

import Foundation
import SalusNavigation
import SalusSmoking
import Testing

@testable import FeatureSmoking

@MainActor
@Suite("SmokingSettingsViewModel", .timeLimit(.minutes(1)))
struct SmokingSettingsViewModelTests {
    typealias Fix = SettingsHarness

    // MARK: State

    @Test("nothing is on show before the first snapshot")
    func nothingBeforeTheFirstSnapshot() {
        let state = SettingsHarness().viewModel().state

        #expect(!state.loaded)
        #expect(state.mode == .none)
    }

    @Test("a quit plan shows its figures and no evening reminder")
    func quitPlanShowsItsFigures() async {
        let harness = SettingsHarness(Fix.quitInput(plan: Fix.plan(reason: "Kızım için", notifications: true)))

        let state = await harness.loadedViewModel().state

        #expect(state.mode == .quit)
        // The latest price period that has begun.
        #expect(state.unitCostMinor == 475)
        #expect(state.currencyCode == "TRY")
        #expect(state.quitAtMs == harness.nowMs - 42 * dayMs)
        #expect(state.reason == "Kızım için")
        #expect(state.notificationsEnabled)
        // The evening reminder and the limit are REDUCE rows; the quit date is a QUIT one.
        #expect(!state.showEveningReminder)
        #expect(!state.showLimit)
        #expect(state.showQuitDate)
    }

    @Test("a reduce plan shows the limit and the evening reminder and no quit date")
    func reducePlanShowsLimitAndEvening() async {
        let harness = SettingsHarness(Fix.reduceInput(plan: Fix.plan(.reduce, evening: true)))

        let state = await harness.loadedViewModel().state

        #expect(state.mode == .reduce)
        #expect(state.dailyLimit == 10)
        #expect(state.showEveningReminder)
        #expect(state.eveningReminderEnabled)
        #expect(state.showLimit)
        #expect(!state.showQuitDate)
    }

    @Test("the unit cost is the latest period that has begun, else the earliest")
    func unitCostFollowsThePricePeriods() async {
        let today = SettingsHarness().today
        func input(_ prices: [PricePeriod]) -> SmokingInput {
            let base = Fix.quitInput()
            return SmokingInput(plan: base.plan, prices: prices, attempts: base.attempts, events: [], goal: nil)
        }

        let begun = await SettingsHarness(input([
            PricePeriod(id: "future", effectiveFromEpochDay: today + 5, unitCostMinor: 600),
            PricePeriod(id: "now", effectiveFromEpochDay: today - 10, unitCostMinor: 475)
        ])).loadedViewModel().state
        let notYet = await SettingsHarness(input([
            PricePeriod(id: "later", effectiveFromEpochDay: today + 9, unitCostMinor: 700),
            PricePeriod(id: "soon", effectiveFromEpochDay: today + 3, unitCostMinor: 500)
        ])).loadedViewModel().state

        #expect(begun.unitCostMinor == 475)
        #expect(notYet.unitCostMinor == 500)
    }

    // MARK: Price

    @Test("a new price opens a period today and the old days keep theirs")
    func newPriceOpensAPeriodToday() async {
        let harness = SettingsHarness()
        let vm = await harness.loadedViewModel()
        vm.onEvent(.priceTapped)
        #expect(vm.state.sheet == .price)

        vm.onEvent(.priceSaved(unitCostMinor: 550))
        await waitUntil("the sheet to close") { vm.state.sheet == .none }
        // The state follows the stored rows a hop after the write has landed.
        await waitUntil("the new price") { vm.state.unitCostMinor == 550 }

        // History is kept and today opens a third period.
        #expect(
            harness.store.input.prices.sorted { $0.effectiveFromEpochDay < $1.effectiveFromEpochDay }
                .map(\.unitCostMinor) == [400, 475, 550]
        )
    }

    // MARK: Currency

    @Test("picking another currency asks first and changes nothing yet")
    func pickingACurrencyAsksFirst() async {
        let harness = SettingsHarness()
        let vm = await harness.loadedViewModel()
        vm.onEvent(.currencyTapped)

        vm.onEvent(.currencyPicked("EUR"))

        #expect(vm.state.confirm == .currency("EUR"))
        #expect(harness.store.input.plan?.currencyCode == "TRY")
        #expect(harness.store.commits == 0)
    }

    @Test("confirming a currency change relabels and keeps every saved amount")
    func confirmedCurrencyKeepsSavedAmounts() async throws {
        let harness = SettingsHarness(Fix.quitInput(events: [Fix.slip("s1", agoMs: 3 * dayMs)]))
        let vm = await harness.loadedViewModel()
        guard case let .quit(before) = await harness.repository.snapshotNow() else {
            Issue.record("expected a quit snapshot")
            return
        }
        // A zero would make "kept" vacuous.
        #expect(before.savedMinor > 0)
        let planBefore = try #require(harness.store.input.plan)
        let pricesBefore = harness.store.input.prices
        vm.onEvent(.currencyTapped)
        vm.onEvent(.currencyPicked("EUR"))

        vm.onEvent(.confirmAccepted)
        await waitUntil("the write") { vm.state.confirm == nil && !vm.state.writing }
        // The state follows the stored rows a hop after the write has landed.
        await waitUntil("the new currency") { vm.state.currencyCode == "EUR" }

        guard case let .quit(after) = await harness.repository.snapshotNow() else {
            Issue.record("expected a quit snapshot")
            return
        }
        #expect(after.plan.currencyCode == "EUR")
        // No conversion: the minor amounts are what they were.
        #expect(after.savedMinor == before.savedMinor)
        // The plan is the old plan with the currency and nothing else changed.
        #expect(
            after.plan == SmokingPlan(
                id: planBefore.id,
                mode: planBefore.mode,
                productType: planBefore.productType,
                baselineUnitsPerDay: planBefore.baselineUnitsPerDay,
                dailyLimit: planBefore.dailyLimit,
                currencyCode: "EUR",
                reason: planBefore.reason,
                notificationsEnabled: planBefore.notificationsEnabled,
                eveningReminderEnabled: planBefore.eveningReminderEnabled,
                createdAtMs: planBefore.createdAtMs,
                tzId: planBefore.tzId
            )
        )
        #expect(harness.store.input.prices == pricesBefore)
        #expect(vm.state.currencyCode == "EUR")
        #expect(vm.state.sheet == .none)
    }

    @Test("dismissing the currency confirmation writes nothing")
    func dismissingTheCurrencyConfirmation() async {
        let harness = SettingsHarness()
        let vm = await harness.loadedViewModel()
        vm.onEvent(.currencyTapped)
        vm.onEvent(.currencyPicked("EUR"))

        vm.onEvent(.confirmDismissed)

        #expect(vm.state.confirm == nil)
        #expect(harness.store.commits == 0)
        #expect(vm.state.currencyCode == "TRY")
    }

    @Test("picking the current currency just closes the sheet")
    func pickingTheCurrentCurrency() async {
        let harness = SettingsHarness()
        let vm = await harness.loadedViewModel()
        vm.onEvent(.currencyTapped)

        vm.onEvent(.currencyPicked("TRY"))

        #expect(vm.state.confirm == nil)
        #expect(vm.state.sheet == .none)
        #expect(harness.store.commits == 0)
    }

    // MARK: Quit date

    @Test("a corrected quit date is confirmed before earlier slips detach")
    func correctedQuitDateIsConfirmedFirst() async throws {
        let harness = SettingsHarness(
            Fix.quitInput(events: [Fix.slip("old", agoMs: 10 * dayMs), Fix.slip("recent", agoMs: 2 * dayMs)])
        )
        let vm = await harness.loadedViewModel()
        vm.onEvent(.quitDateTapped)
        #expect(vm.state.sheet == .quitDate(initialMs: harness.nowMs - 42 * dayMs))

        vm.onEvent(.quitDatePicked(harness.nowMs - 5 * dayMs))

        #expect(vm.state.confirm == .quitDate(harness.nowMs - 5 * dayMs))
        // Nothing is written before the confirmation.
        #expect(try #require(harness.store.input.attempts.first).startedAtMs == harness.nowMs - 42 * dayMs)

        vm.onEvent(.confirmAccepted)
        await waitUntil("the write") { vm.state.confirm == nil && !vm.state.writing }

        #expect(try #require(harness.store.input.attempts.first).startedAtMs == harness.nowMs - 5 * dayMs)
        // A slip now before the start detaches.
        #expect(harness.store.input.events.first { $0.id == "old" }?.attemptId == nil)
        #expect(harness.store.input.events.first { $0.id == "recent" }?.attemptId == "attempt-1")
        await waitUntil("the date to follow") { vm.state.quitAtMs == harness.nowMs - 5 * dayMs }
    }

    @Test("a quit date that overlaps the previous attempt is refused and the state stays")
    func overlappingQuitDateIsRefused() async {
        let harness = SettingsHarness(
            Fix.quitInput(attempts: [
                QuitAttempt(
                    id: "attempt-0",
                    startedAtMs: Fix.nowMs - 80 * dayMs,
                    tzId: Fix.zoneId,
                    endedAtMs: Fix.nowMs - 50 * dayMs,
                    endReason: .restarted
                ),
                QuitAttempt(
                    id: "attempt-1",
                    startedAtMs: Fix.nowMs - 50 * dayMs,
                    tzId: Fix.zoneId,
                    endedAtMs: nil,
                    endReason: nil
                )
            ])
        )
        let vm = await harness.loadedViewModel()
        vm.onEvent(.quitDateTapped)
        vm.onEvent(.quitDatePicked(harness.nowMs - 60 * dayMs))

        vm.onEvent(.confirmAccepted)
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.overlap)])
        #expect(harness.store.input.attempts.last?.startedAtMs == harness.nowMs - 50 * dayMs)
        #expect(vm.state.quitAtMs == harness.nowMs - 50 * dayMs)
        // The dialog closes: its question is answered.
        #expect(vm.state.confirm == nil)
        #expect(!vm.state.writing)
    }

    // MARK: Limit and reason

    @Test("a new limit is saved and the rest of the plan is kept")
    func newLimitKeepsTheRestOfThePlan() async throws {
        let harness = SettingsHarness(
            Fix.reduceInput(plan: Fix.plan(.reduce, reason: "Nefes", notifications: true, evening: true))
        )
        let vm = await harness.loadedViewModel()
        vm.onEvent(.limitTapped)
        #expect(vm.state.sheet == .limit)

        vm.onEvent(.limitSaved(7))
        await waitUntil("the sheet to close") { vm.state.sheet == .none }

        let saved = try #require(harness.store.input.plan)
        #expect(saved.dailyLimit == 7)
        #expect(saved.reason == "Nefes")
        #expect(saved.notificationsEnabled)
        #expect(saved.eveningReminderEnabled)
    }

    @Test("a limit of zero is refused with a message and the sheet stays")
    func zeroLimitIsRefused() async {
        let harness = SettingsHarness(Fix.reduceInput())
        let vm = await harness.loadedViewModel()
        vm.onEvent(.limitTapped)

        vm.onEvent(.limitSaved(0))
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.invalid)])
        #expect(harness.store.input.plan?.dailyLimit == 10)
        #expect(vm.state.sheet == .limit)
    }

    @Test("a reason is trimmed, kept and cleared by a blank")
    func reasonIsTrimmedAndClearedByABlank() async {
        let harness = SettingsHarness()
        let vm = await harness.loadedViewModel()
        vm.onEvent(.reasonTapped)

        vm.onEvent(.reasonSaved("  Kızım için "))
        await waitUntil("the reason") { vm.state.reason == "Kızım için" }
        #expect(harness.store.input.plan?.reason == "Kızım için")

        vm.onEvent(.reasonTapped)
        vm.onEvent(.reasonSaved("   "))
        await waitUntil("the reason to clear") { vm.state.reason == nil }
        #expect(harness.store.input.plan?.reason == nil)
    }

    @Test("a sheet cannot be dismissed while its write is in flight")
    func sheetStaysWhileWriting() async {
        let harness = SettingsHarness()
        let vm = await harness.loadedViewModel()
        vm.onEvent(.reasonTapped)
        let gate = WriteGate()
        harness.store.gate = gate
        vm.onEvent(.reasonSaved("Nefes"))

        vm.onEvent(.sheetDismissed)

        #expect(vm.state.sheet == .reason)
        gate.open()
        await waitUntil("the sheet to close") { vm.state.sheet == .none }
    }

    @Test("a storage fault is reported generically and the sheet stays")
    func storageFaultIsGeneric() async {
        let harness = SettingsHarness()
        let vm = await harness.loadedViewModel()
        vm.onEvent(.priceTapped)
        harness.store.failure = FakeStorageFault()

        vm.onEvent(.priceSaved(unitCostMinor: 550))
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.generic)])
        #expect(vm.state.sheet == .price)
        #expect(!vm.state.writing)
    }
}
