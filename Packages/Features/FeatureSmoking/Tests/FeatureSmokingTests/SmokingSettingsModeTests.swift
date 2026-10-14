// Ported from `feature/smoking/src/test/kotlin/com/alicansekban/salus/feature/smoking/ui/settings/
// SmokingSettingsViewModelTest.kt` (the notification, mode and reset regions; the rest is in
// `SmokingSettingsViewModelTests.swift`).
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
@Suite("SmokingSettingsViewModel switches, mode and reset", .timeLimit(.minutes(1)))
struct SmokingSettingsModeTests {
    typealias Fix = SettingsHarness

    // MARK: Notifications

    @Test("turning notifications on with the permission just saves the switch")
    func notificationsOnWithPermission() async {
        let harness = SettingsHarness(notificationsAuthorized: true)
        let vm = await harness.loadedViewModel()

        vm.onEvent(.notificationsToggled(true))
        await waitUntil("the switch") { vm.state.notificationsEnabled }

        #expect(vm.pendingEffects.isEmpty)
        #expect(harness.store.input.plan?.notificationsEnabled == true)
    }

    @Test("turning notifications on without the permission opens the reminder health screen")
    func notificationsOnWithoutPermission() async {
        let harness = SettingsHarness(notificationsAuthorized: false)
        let vm = await harness.loadedViewModel()

        vm.onEvent(.notificationsToggled(true))
        await waitUntil("the effect") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.openReminderHealth])
        // The choice is kept, the permission is the next step.
        #expect(harness.store.input.plan?.notificationsEnabled == true)
    }

    @Test("turning notifications off never asks for the permission")
    func notificationsOffNeverAsks() async {
        let harness = SettingsHarness(
            Fix.quitInput(plan: Fix.plan(notifications: true)),
            notificationsAuthorized: false
        )
        let vm = await harness.loadedViewModel()

        vm.onEvent(.notificationsToggled(false))
        await waitUntil("the switch") { !vm.state.notificationsEnabled }

        #expect(vm.pendingEffects.isEmpty)
        #expect(harness.store.input.plan?.notificationsEnabled == false)
    }

    @Test("the evening reminder switch writes its own flag and needs the permission too")
    func eveningSwitchWritesItsOwnFlag() async throws {
        let harness = SettingsHarness(
            Fix.reduceInput(plan: Fix.plan(.reduce, notifications: true)),
            notificationsAuthorized: false
        )
        let vm = await harness.loadedViewModel()

        vm.onEvent(.eveningToggled(true))
        await waitUntil("the effect") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.openReminderHealth])
        let saved = try #require(harness.store.input.plan)
        #expect(saved.eveningReminderEnabled)
        // The other switch is untouched and the limit is carried through the write.
        #expect(saved.notificationsEnabled)
        #expect(saved.dailyLimit == 10)
    }

    // MARK: Mode

    @Test("switching from quit to reduce takes a limit, closes the attempt and keeps the entries")
    func quitToReduce() async throws {
        let harness = SettingsHarness(Fix.quitInput(events: [Fix.slip("s1", agoMs: 3 * dayMs)]))
        let vm = await harness.loadedViewModel()
        vm.onEvent(.switchModeTapped)
        #expect(vm.state.sheet == .switchToReduce(suggestedLimit: 16))

        vm.onEvent(.switchToReduceConfirmed(limit: 12))
        await waitUntil("reduce mode") { vm.state.mode == .reduce && vm.state.sheet == .none }

        let stored = harness.store.input
        #expect(stored.plan?.mode == .reduce)
        #expect(stored.plan?.dailyLimit == 12)
        #expect(try #require(stored.attempts.first).endReason == .switchedToReduce)
        #expect(stored.events.map(\.id) == ["s1"])
    }

    @Test("switching from reduce to quit takes a quit time and opens an attempt")
    func reduceToQuit() async {
        let harness = SettingsHarness(Fix.reduceInput())
        let vm = await harness.loadedViewModel()
        vm.onEvent(.switchModeTapped)
        #expect(vm.state.sheet == .switchToQuit(initialMs: harness.nowMs))

        vm.onEvent(.switchToQuitConfirmed(quitAtMs: harness.nowMs - dayMs))
        await waitUntil("quit mode") { vm.state.mode == .quit }

        #expect(harness.store.input.plan?.mode == .quit)
        #expect(harness.store.input.plan?.dailyLimit == nil)
        #expect(harness.store.input.attempts.last?.startedAtMs == harness.nowMs - dayMs)
    }

    @Test("a quit time before the previous attempt ended is refused and the mode stays")
    func quitTimeBeforeThePreviousAttemptIsRefused() async {
        let harness = SettingsHarness(Fix.reduceInput())
        let vm = await harness.loadedViewModel()
        vm.onEvent(.switchModeTapped)

        vm.onEvent(.switchToQuitConfirmed(quitAtMs: harness.nowMs - 70 * dayMs))
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.overlap)])
        #expect(harness.store.input.plan?.mode == .reduce)
        #expect(harness.store.input.attempts.count == 1)
        #expect(vm.state.mode == .reduce)
        #expect(!vm.state.writing)
    }

    @Test("a future quit time is refused with its own message")
    func futureQuitTimeIsRefused() async {
        let harness = SettingsHarness(Fix.reduceInput())
        let vm = await harness.loadedViewModel()
        vm.onEvent(.switchModeTapped)

        vm.onEvent(.switchToQuitConfirmed(quitAtMs: harness.nowMs + dayMs))
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.futureDate)])
        #expect(vm.state.sheet == .switchToQuit(initialMs: harness.nowMs))
    }

    // MARK: Reset

    @Test("reset asks first and writes nothing until it is confirmed")
    func resetAsksFirst() async {
        let harness = SettingsHarness(Fix.quitInput(events: [Fix.slip("s1", agoMs: dayMs)]))
        let vm = await harness.loadedViewModel()

        vm.onEvent(.resetTapped)

        #expect(vm.state.confirm == .reset)
        #expect(harness.store.commits == 0)
        #expect(harness.navigator.commandLog.isEmpty)

        vm.onEvent(.confirmDismissed)
        #expect(vm.state.confirm == nil)
        #expect(harness.store.commits == 0)
    }

    @Test("a confirmed reset empties the tables and leaves both smoking screens")
    func confirmedResetLeavesBothScreens() async {
        let harness = SettingsHarness(Fix.quitInput(events: [Fix.slip("s1", agoMs: dayMs)]))
        let vm = await harness.loadedViewModel()
        vm.onEvent(.resetTapped)

        vm.onEvent(.confirmAccepted)
        await waitUntil("both pops") { harness.navigator.commandLog.count == 2 }

        #expect(harness.store.input == FakeSmokingStore.empty)
        // Settings, then the main screen under it: back at the screen smoking was opened from.
        #expect(harness.navigator.commandLog == [.pop, .pop])
        await waitUntil("the state to follow") { vm.state.mode == .none }
    }

    @Test("a double tap on the reset confirmation resets once")
    func doubleTapResetsOnce() async {
        let harness = SettingsHarness()
        let vm = await harness.loadedViewModel()
        let gate = WriteGate()
        harness.store.gate = gate
        vm.onEvent(.resetTapped)
        let callsBefore = harness.store.calls

        vm.onEvent(.confirmAccepted)
        vm.onEvent(.confirmAccepted)
        gate.open()
        await waitUntil("both pops") { harness.navigator.commandLog.count == 2 }

        #expect(harness.store.calls - callsBefore == 1)
        #expect(harness.navigator.commandLog.count == 2)
    }

    @Test("a refused reset drops the dialog, stays on the screen and says so")
    func failedResetStaysPut() async {
        let harness = SettingsHarness()
        let vm = await harness.loadedViewModel()
        vm.onEvent(.resetTapped)
        harness.store.failure = FakeStorageFault()

        vm.onEvent(.confirmAccepted)
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.generic)])
        #expect(vm.state.confirm == nil)
        #expect(harness.navigator.commandLog.isEmpty)
    }
}
