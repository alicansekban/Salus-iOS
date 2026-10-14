// Ported from `feature/smoking/src/test/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// SmokingMainViewModelTest.kt`, minus the clock cases: Android's ViewModel runs the ticker, here
// the view's `TimelineView` does, and its cadence is pinned in `SmokingMainTimeTests`.
//
// Beyond the Kotlin cases: the double-confirm case runs on the restart path as well (the Task 6
// review found `ResolveSlip` with `restart` writes twice if a second tap gets through), and the
// trigger case runs after a restart, where the slip belongs to the attempt it closed.

import Foundation
import SalusNavigation
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

@MainActor
@Suite("SmokingMainViewModel", .timeLimit(.minutes(1)))
struct SmokingMainViewModelTests {
    let harness = MainHarness()

    // MARK: State

    @Test("the state carries the quit snapshot once the first one arrives")
    func stateCarriesTheQuitSnapshot() async throws {
        let vm = harness.viewModel()
        #expect(vm.state.snapshot == nil)
        await waitUntil("the first snapshot") { vm.state.snapshot != nil }

        let snapshot = try vm.quit()
        #expect(snapshot.attemptStartedAtMs == harness.nowMs - 42 * dayMs)
        #expect(snapshot.attemptElapsedMs == 42 * dayMs)
    }

    // MARK: Slip sheet

    @Test("smoked tapped opens the slip sheet at one unit")
    func smokedTappedOpensTheSlipSheet() async {
        let vm = await harness.subscribedViewModel()

        vm.onEvent(.smokedTapped)

        #expect(vm.state.sheet == .slip(units: 1))
    }

    @Test("continuing after a slip keeps the attempt and opens the trigger sheet for the new event")
    func continuingKeepsTheAttempt() async throws {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.smokedTapped)

        vm.onEvent(.slipConfirmed(units: 2, restart: false))
        await waitUntil("the trigger sheet") { vm.state.sheet != .slip(units: 1) }

        let input = harness.store.input
        #expect(input.attempts.map(\.id) == ["attempt-1"])
        #expect(input.attempts.first?.endedAtMs == nil)
        let event = try #require(input.events.first)
        #expect(input.events.count == 1)
        #expect(event.type == .smoked)
        #expect(event.units == 2)
        #expect(event.attemptId == "attempt-1")
        #expect(vm.state.sheet == .trigger(eventId: event.id))
        #expect(!vm.state.writing)
        await waitUntil("the new snapshot") { (try? vm.quit().slipCount) == 1 }
        #expect(try vm.quit().attemptId == "attempt-1")
    }

    @Test("starting over closes the attempt as restarted and counts from a new one")
    func startingOverClosesTheAttempt() async throws {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.smokedTapped)

        vm.onEvent(.slipConfirmed(units: 1, restart: true))
        await waitUntil("the new attempt") { (try? vm.quit().attemptId) != "attempt-1" }

        let attempts = harness.store.input.attempts
        #expect(attempts.count == 2)
        let closed = try #require(attempts.first { $0.id == "attempt-1" })
        #expect(closed.endReason == .restarted)
        #expect(closed.endedAtMs == harness.nowMs)
        #expect(try vm.quit().attemptStartedAtMs == harness.nowMs)
        #expect(harness.store.input.events.first?.attemptId == "attempt-1")
        guard case .trigger = vm.state.sheet else {
            Issue.record("expected the trigger sheet, got \(String(describing: vm.state.sheet))")
            return
        }
    }

    @Test("dismissing the slip sheet writes nothing")
    func dismissingWritesNothing() async {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.smokedTapped)

        vm.onEvent(.slipDismissed)
        await Task.yield()

        #expect(vm.state.sheet == nil)
        #expect(harness.store.calls == 0)
        #expect(harness.store.input.events.isEmpty)
    }

    @Test("a second confirm while the first write is in flight writes once", arguments: [false, true])
    func secondConfirmWritesOnce(restart: Bool) async {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.smokedTapped)
        let gate = WriteGate()
        harness.store.gate = gate

        vm.onEvent(.slipConfirmed(units: 1, restart: restart))
        #expect(vm.state.writing, "buttons are disabled from the first tap on")
        vm.onEvent(.slipConfirmed(units: 1, restart: restart))
        await waitUntil("the first write is started") { harness.store.calls == 1 }
        gate.open()
        await waitUntil("the write ends") { !vm.state.writing }

        #expect(harness.store.calls == 1)
        #expect(harness.store.input.events.count == 1)
        #expect(harness.store.input.attempts.count == (restart ? 2 : 1), "a restart opens one attempt, not two")
    }

    @Test("dismissing the slip sheet while its write is in flight is ignored")
    func dismissingDuringTheWriteIsIgnored() async {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.smokedTapped)
        let gate = WriteGate()
        harness.store.gate = gate
        vm.onEvent(.slipConfirmed(units: 1, restart: false))

        vm.onEvent(.slipDismissed)
        #expect(vm.state.sheet == .slip(units: 1), "the sheet stays until the write ends")
        gate.open()
        await waitUntil("the trigger sheet") { vm.state.sheet != .slip(units: 1) }

        guard case .trigger = vm.state.sheet else {
            Issue.record("expected the trigger sheet")
            return
        }
    }

    @Test("a refused slip shows an error and leaves the sheet and the data alone")
    func refusedSlipShowsAnError() async {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.smokedTapped)

        // Zero units is invalid input: the use case refuses it, as a failed write would.
        vm.onEvent(.slipConfirmed(units: 0, restart: false))
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError])
        #expect(vm.state.sheet == .slip(units: 1))
        #expect(!vm.state.writing)
        #expect(harness.store.input.events.isEmpty)
    }

    // MARK: Trigger sheet

    @Test("saving a trigger lands on the event the slip wrote and no other")
    func triggerLandsOnTheSlip() async throws {
        let earlier = harness.craving(id: "craving-1", atMs: harness.nowMs - dayMs)
        let harness = MainHarness(events: [earlier])
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.smokedTapped)
        vm.onEvent(.slipConfirmed(units: 3, restart: false))
        await waitUntil("the trigger sheet") { vm.state.sheet != .slip(units: 1) }
        guard case let .trigger(slipId) = vm.state.sheet else {
            Issue.record("expected the trigger sheet")
            return
        }

        vm.onEvent(.triggerSaved(trigger: .coffee, intensity: 4))
        await waitUntil("the sheet closes") { vm.state.sheet == nil }

        let events = Dictionary(uniqueKeysWithValues: harness.store.input.events.map { ($0.id, $0) })
        let slip = try #require(events[slipId])
        #expect(slip.trigger == .coffee)
        #expect(slip.intensity == 4)
        #expect(slip.units == 3, "the edit keeps what the slip logged")
        #expect(slip.occurredAtMs == harness.nowMs)
        #expect(events["craving-1"]?.trigger == nil, "another event is untouched")
    }

    @Test("a trigger saved after starting over stays on the attempt the slip closed")
    func triggerAfterRestartKeepsTheClosedAttempt() async throws {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.smokedTapped)
        vm.onEvent(.slipConfirmed(units: 1, restart: true))
        await waitUntil("the trigger sheet") { vm.state.sheet != .slip(units: 1) }

        vm.onEvent(.triggerSaved(trigger: .stress, intensity: nil))
        await waitUntil("the sheet closes") { vm.state.sheet == nil }

        let event = try #require(harness.store.input.events.first)
        #expect(harness.store.input.events.count == 1)
        #expect(event.trigger == .stress)
        #expect(event.attemptId == "attempt-1")
        #expect(harness.store.input.attempts.count == 2)
    }

    @Test("skipping the trigger closes the sheet and leaves the event as logged")
    func skippingLeavesTheEventAsLogged() async {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.smokedTapped)
        vm.onEvent(.slipConfirmed(units: 1, restart: false))
        await waitUntil("the trigger sheet") { vm.state.sheet != .slip(units: 1) }
        let commits = harness.store.commits

        vm.onEvent(.triggerSkipped)

        #expect(vm.state.sheet == nil)
        #expect(harness.store.commits == commits)
        #expect(harness.store.input.events.first?.trigger == nil)
    }

    @Test("saving with nothing chosen closes the sheet and writes nothing")
    func savingNothingWritesNothing() async {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.smokedTapped)
        vm.onEvent(.slipConfirmed(units: 1, restart: false))
        await waitUntil("the trigger sheet") { vm.state.sheet != .slip(units: 1) }
        let commits = harness.store.commits

        vm.onEvent(.triggerSaved(trigger: nil, intensity: nil))

        #expect(vm.state.sheet == nil)
        #expect(harness.store.commits == commits)
    }

    @Test("a second save while the first is in flight writes once")
    func secondSaveWritesOnce() async {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.smokedTapped)
        vm.onEvent(.slipConfirmed(units: 1, restart: false))
        await waitUntil("the trigger sheet") { vm.state.sheet != .slip(units: 1) }
        let before = harness.store.calls
        let gate = WriteGate()
        harness.store.gate = gate

        vm.onEvent(.triggerSaved(trigger: .coffee, intensity: nil))
        vm.onEvent(.triggerSaved(trigger: .coffee, intensity: nil))
        await waitUntil("the write is started") { harness.store.calls == before + 1 }
        gate.open()
        await waitUntil("the sheet closes") { vm.state.sheet == nil }

        #expect(harness.store.calls == before + 1)
    }

    // MARK: Navigation

    @Test("the craving button, the stage card, history and settings navigate")
    func buttonsNavigate() async throws {
        let vm = await harness.subscribedViewModel()
        let nextStageId = try #require(vm.quit().nextStage?.stageId)

        vm.onEvent(.cravingTapped)
        vm.onEvent(.stageTapped)
        vm.onEvent(.historyTapped)
        vm.onEvent(.settingsTapped)
        await waitUntil("four commands") { harness.navigator.commandLog.count == 4 }

        #expect(
            harness.navigator.commandLog == [
                .navigate(AnyNavKey(SmokingCravingKey(source: "main"))),
                .navigate(AnyNavKey(SmokingTimelineKey(highlightStageId: nextStageId))),
                .navigate(AnyNavKey(SmokingHistoryKey())),
                .navigate(AnyNavKey(SmokingSettingsKey()))
            ]
        )
    }
}
