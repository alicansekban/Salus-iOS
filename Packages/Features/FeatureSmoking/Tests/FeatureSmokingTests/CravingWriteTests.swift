// Ported from the "Geçti", exits and "Sigara içtim" cases of `feature/smoking/src/test/kotlin/com/
// alicansekban/salus/feature/smoking/ui/craving/CravingViewModelTest.kt`. The timer, rhythm and
// lines are in `CravingTimerTests`.
//
// Not ported: "a logged craving survives a process death and is not written twice". It needs the
// saved state Android's ViewModel keeps; iOS keeps nothing across a termination, so there is no
// restored "logged" to guard — `CravingTimerTests` pins that a rebuilt ViewModel writes nothing.

import Foundation
import SalusNavigation
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

@MainActor
@Suite("CravingViewModel writes and exits", .timeLimit(.minutes(1)))
struct CravingWriteTests {
    let harness = CravingHarness()

    // MARK: "Geçti"

    @Test("passed writes one craving, stamped now, and shows the count")
    func passedWritesOne() async throws {
        let vm = await harness.readyViewModel()
        harness.setClock(secondsAfterStart: 90)
        vm.refreshClock()

        vm.onEvent(.passedTapped)
        await waitUntil("the craving is logged") { vm.state.logged }

        let event = try #require(harness.resisted.first)
        #expect(harness.resisted.count == 1)
        #expect(event.occurredAtMs == harness.nowMs + 90000)
        #expect(vm.state.completed)
        // Two cravings were beaten before; this one is the third.
        #expect(vm.state.loggedCount == 3)
        #expect(!vm.state.writing)
    }

    @Test("in QUIT the count is the active attempt's, not the all-time one")
    func quitCountsTheAttempt() async {
        // Three cravings beaten in an earlier attempt and two in this one: the Main tile counts this
        // attempt (2), so this craving is its third, not the sixth.
        let quit = CravingHarness(earlierAttemptCravings: 3)
        let vm = await quit.readyViewModel()

        vm.onEvent(.passedTapped)
        await waitUntil("the craving is logged") { vm.state.logged }

        #expect(vm.state.loggedCount == 3)
    }

    @Test("in REDUCE the count is the all-time one")
    func reduceCountsAllTime() async {
        let events = (0 ..< 4).map { CravingHarness.craving(id: "r-\($0)", attemptId: nil) }
        let reduce = CravingHarness(mode: .reduce, extraEvents: events)
        let vm = await reduce.readyViewModel()

        vm.onEvent(.passedTapped)
        await waitUntil("the craving is logged") { vm.state.logged }

        #expect(vm.state.loggedCount == 5)
    }

    @Test("a double tap on passed writes once")
    func doublePassedWritesOnce() async {
        let vm = await harness.readyViewModel()
        let gate = WriteGate()
        harness.store.gate = gate

        vm.onEvent(.passedTapped)
        vm.onEvent(.passedTapped)
        await waitUntil("the first write is started") { harness.store.calls == 1 }
        gate.open()
        await waitUntil("the craving is logged") { vm.state.logged }
        vm.onEvent(.passedTapped)
        await Task.yield()

        #expect(harness.resisted.count == 1)
        #expect(harness.store.calls == 1)
    }

    @Test("passed after the timer ran out still writes, and only then")
    func passedAfterTheTimer() async throws {
        let vm = await harness.readyViewModel()
        harness.setClock(secondsAfterStart: 6 * 60)
        vm.refreshClock()
        #expect(vm.state.completed)
        #expect(harness.store.commits == 0)

        vm.onEvent(.passedTapped)
        await waitUntil("the craving is logged") { vm.state.logged }

        let event = try #require(harness.resisted.first)
        #expect(harness.resisted.count == 1)
        #expect(event.occurredAtMs == harness.nowMs + 6 * 60000)
    }

    @Test("a failed write is reported and leaves the flow as it was")
    func failedWrite() async {
        let vm = await harness.readyViewModel()
        harness.store.failure = FakeStorageFault()

        vm.onEvent(.passedTapped)
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError])
        #expect(!vm.state.logged)
        #expect(!vm.state.writing)
    }

    @Test("continue after passed opens the trigger sheet on the new craving")
    func continueOpensTheTriggerSheet() async throws {
        let vm = await harness.readyViewModel()
        vm.onEvent(.passedTapped)
        await waitUntil("the craving is logged") { vm.state.logged }

        vm.onEvent(.continueTapped)

        let event = try #require(harness.resisted.first)
        #expect(vm.state.sheet == .trigger(eventId: event.id))
    }

    @Test("continue before anything is logged does nothing")
    func continueNeedsALoggedCraving() async {
        let vm = await harness.readyViewModel()

        vm.onEvent(.continueTapped)

        #expect(vm.state.sheet == nil)
    }

    @Test("saving a trigger edits that craving and leaves the screen")
    func savingATrigger() async throws {
        let vm = await harness.readyViewModel()
        vm.onEvent(.passedTapped)
        await waitUntil("the craving is logged") { vm.state.logged }
        vm.onEvent(.continueTapped)

        vm.onEvent(.triggerSaved(trigger: .coffee, intensity: 4))
        await waitUntil("the screen is left") { harness.cover.closes > 0 }

        let event = try #require(harness.resisted.first)
        #expect(event.trigger == .coffee)
        #expect(event.intensity == 4)
        #expect(event.occurredAtMs == harness.nowMs)
        #expect(harness.cover.closes == 1)
    }

    @Test("skipping the trigger leaves the craving as logged and leaves the screen")
    func skippingTheTrigger() async {
        let vm = await harness.readyViewModel()
        vm.onEvent(.passedTapped)
        await waitUntil("the craving is logged") { vm.state.logged }
        let committed = harness.store.commits
        vm.onEvent(.continueTapped)

        vm.onEvent(.triggerSkipped)
        await waitUntil("the screen is left") { harness.cover.closes > 0 }

        #expect(harness.store.commits == committed)
        #expect(harness.cover.closes == 1)
    }

    // MARK: Exits that write nothing

    @Test("closing early writes nothing and leaves")
    func closingEarly() async {
        let vm = await harness.readyViewModel()
        harness.setClock(secondsAfterStart: 40)
        vm.refreshClock()

        vm.onEvent(.closeTapped)
        await waitUntil("the screen is left") { harness.cover.closes > 0 }

        #expect(harness.store.calls == 0)
        #expect(harness.cover.closes == 1)
    }

    @Test("closing is ignored while a write is in flight")
    func closingWhileWriting() async {
        let vm = await harness.readyViewModel()
        let gate = WriteGate()
        harness.store.gate = gate
        vm.onEvent(.passedTapped)
        await waitUntil("the write is started") { harness.store.calls == 1 }

        vm.onEvent(.closeTapped)
        await Task.yield()

        #expect(harness.cover.closes == 0)
        gate.open()
        await waitUntil("the craving is logged") { vm.state.logged }
    }

    @Test("a second tap on close does not send a second pop")
    func doubleCloseLeavesOnce() async {
        let vm = await harness.readyViewModel()

        vm.onEvent(.closeTapped)
        vm.onEvent(.closeTapped)
        await waitUntil("the screen is left") { harness.cover.closes > 0 }
        for _ in 0 ..< 20 {
            await Task.yield()
        }

        #expect(harness.cover.closes == 1)
    }

    @Test("the ViewModel is released once the screen is left")
    func viewModelIsReleased() async {
        var vm: CravingViewModel? = await harness.readyViewModel()
        weak var probe = vm
        vm?.onEvent(.closeTapped)
        await waitUntil("the screen is left") { harness.cover.closes > 0 }

        vm = nil
        await Task.yield()

        #expect(probe == nil, "the snapshot observation or a write still holds the ViewModel")
    }

    // MARK: "Sigara içtim"

    @Test("in QUIT the smoked button opens the slip sheet and writes nothing")
    func quitSmokedOpensTheSlipSheet() async {
        let vm = await harness.readyViewModel()

        vm.onEvent(.smokedTapped)

        #expect(vm.state.sheet == .slip)
        #expect(harness.store.calls == 0)
        #expect(harness.cover.closes == 0)
    }

    @Test("dismissing the slip sheet stays on the craving screen")
    func dismissingTheSlipSheet() async {
        let vm = await harness.readyViewModel()
        vm.onEvent(.smokedTapped)

        vm.onEvent(.slipDismissed)
        await Task.yield()

        #expect(vm.state.sheet == nil)
        #expect(harness.store.calls == 0)
        #expect(harness.cover.closes == 0)
    }

    @Test("confirming a slip writes it once and asks what triggered it")
    func confirmingASlip() async throws {
        let vm = await harness.readyViewModel()
        vm.onEvent(.smokedTapped)

        vm.onEvent(.slipConfirmed(units: 2, restart: false))
        vm.onEvent(.slipConfirmed(units: 2, restart: false))
        await waitUntil("the trigger sheet") { vm.state.sheet != .slip }

        let slip = try #require(harness.smoked.first)
        #expect(harness.smoked.count == 1)
        #expect(slip.units == 2)
        #expect(vm.state.sheet == .trigger(eventId: slip.id))
        // The craving itself was not beaten, so no craving is written.
        #expect(harness.resisted.isEmpty)
    }

    @Test("the slip's trigger keeps the units and leaves the screen")
    func slipTriggerKeepsTheUnits() async throws {
        let vm = await harness.readyViewModel()
        vm.onEvent(.smokedTapped)
        vm.onEvent(.slipConfirmed(units: 2, restart: false))
        await waitUntil("the trigger sheet") { vm.state.sheet != .slip }

        vm.onEvent(.triggerSaved(trigger: .stress, intensity: nil))
        await waitUntil("the screen is left") { harness.cover.closes > 0 }

        let slip = try #require(harness.smoked.first)
        #expect(slip.units == 2)
        #expect(slip.trigger == .stress)
        #expect(harness.cover.closes == 1)
    }

    @Test("in REDUCE the smoked button logs one unit and leaves")
    func reduceSmokedLogsOne() async throws {
        let reduce = CravingHarness(mode: .reduce)
        let vm = await reduce.readyViewModel()

        vm.onEvent(.smokedTapped)
        await waitUntil("the screen is left") { reduce.cover.closes > 0 }

        let entry = try #require(reduce.smoked.first)
        #expect(reduce.smoked.count == 1)
        #expect(entry.units == 1)
        #expect(reduce.cover.closes == 1)
    }

    @Test("a double tap on smoked in REDUCE writes once")
    func reduceDoubleSmoked() async {
        let reduce = CravingHarness(mode: .reduce)
        let vm = await reduce.readyViewModel()
        let gate = WriteGate()
        reduce.store.gate = gate

        vm.onEvent(.smokedTapped)
        vm.onEvent(.smokedTapped)
        await waitUntil("the write is started") { reduce.store.calls == 1 }
        gate.open()
        await waitUntil("the screen is left") { reduce.cover.closes > 0 }

        #expect(reduce.smoked.count == 1)
        #expect(reduce.store.calls == 1)
    }

    @Test("a write finishing after the cover was closed from outside pops no screen")
    func writeFinishingAfterAnExternalCloseTouchesNoStack() async {
        let reduce = CravingHarness(mode: .reduce)
        let vm = await reduce.readyViewModel()
        let gate = WriteGate()
        reduce.store.gate = gate
        vm.onEvent(.smokedTapped)
        await waitUntil("the write is started") { reduce.store.calls == 1 }

        // A notification tap closes the cover and pushes its screen onto the tab stack.
        reduce.cover.presenter.dismiss()
        gate.open()
        await waitUntil("the write is done") { reduce.smoked.count == 1 }
        await waitUntil("the screen asks to leave") { reduce.cover.closes > 0 }
        for _ in 0 ..< 20 {
            await Task.yield()
        }

        // The close ran once, and landed on a cover that was already gone: no stack command at
        // all, and no cover is up.
        #expect(reduce.cover.closes == 1)
        #expect(reduce.cover.stack.commandLog.isEmpty)
        #expect(reduce.cover.presenter.presented == nil)
    }

    @Test("smoked does nothing before the snapshot says which mode this is")
    func smokedBeforeTheSnapshot() async {
        let vm = harness.viewModel()

        vm.onEvent(.smokedTapped)

        #expect(vm.state.sheet == nil)
        #expect(harness.store.calls == 0)
        await waitUntil("the first snapshot") { vm.state.mode != nil }
    }
}
