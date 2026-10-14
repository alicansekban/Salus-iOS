// The second half of the Kotlin `SmokingSetupViewModelTest`: the quit date, back and start, and the
// refusals — split from `SmokingSetupViewModelTests` only to keep each suite under the 300-line
// `type_body_length`.

import Foundation
import SalusCommon
import SalusModel
import SalusNavigation
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

@MainActor
@Suite("SmokingSetupViewModel flow", .timeLimit(.minutes(1)))
struct SmokingSetupFlowTests: SetupSuite {
    let harness = SetupHarness()

    // MARK: Quit date

    @Test("a quit date in the future is rejected and the date stays where it was")
    func futureQuitDateIsRejected() {
        let vm = viewModel()

        vm.onEvent(.quitAtChanged(nowMs + 1))

        #expect(vm.state.quitAtMs == nowMs)
        #expect(vm.pendingEffects == [.showError(.futureDate)])
    }

    @Test("a past quit date is kept and written as the attempt start")
    func pastQuitDateIsTheAttemptStart() async throws {
        let vm = viewModel()
        let past = try ms("2026-03-08T09:30")
        vm.onEvent(.quitAtChanged(past))
        vm.onEvent(.reasonChanged("  For my daughter  "))
        toDetailsStep(vm)
        vm.onEvent(.continueClicked)
        await waitUntil("the plan is written") { store.commits == 1 }

        #expect(store.input.attempts.first?.startedAtMs == past)
        #expect(store.input.plan?.reason == "For my daughter")
    }

    @Test("the now shortcut moves the quit date to the clock's now")
    func nowShortcutFollowsTheClock() throws {
        let vm = viewModel()
        try vm.onEvent(.quitAtChanged(ms("2026-03-01T08:00")))
        clock.advanceTo(Date(timeIntervalSince1970: 1_773_133_290))

        vm.onEvent(.quitNowClicked)

        #expect(vm.state.quitAtMs == nowMs + 90000)
        #expect(!vm.state.quitAtEdited)
    }

    // MARK: Back and start

    @Test("back from the first step leaves the wizard and writes nothing")
    func backFromTheFirstStepLeaves() async {
        let vm = viewModel()

        vm.onEvent(.backClicked)
        await waitUntil("the pop is recorded") { navigator.commandLog.count == 1 }

        #expect(navigator.commandLog == [.pop])
        #expect(store.input.plan == nil)
        #expect(store.commits == 0)
    }

    @Test("back from a later step returns to the step before without leaving")
    func backFromALaterStepStepsBack() async {
        let vm = viewModel()
        vm.onEvent(.continueClicked)
        vm.onEvent(.continueClicked)
        #expect(vm.state.step == .amount)

        vm.onEvent(.backClicked)
        await Task.yield()

        #expect(vm.state.step == .product)
        #expect(navigator.commandLog.isEmpty)
    }

    @Test("changing the product from the amount step goes back to the product step")
    func changeProductGoesBack() {
        let vm = viewModel()
        vm.onEvent(.productSelected(.vape))
        vm.onEvent(.continueClicked)
        vm.onEvent(.continueClicked)
        #expect(vm.state.step == .amount)

        vm.onEvent(.changeProductClicked)

        #expect(vm.state.step == .product)
    }

    @Test("start writes the plan and then replaces the setup with the main screen")
    func startReplacesTheSetupWithTheMainScreen() async throws {
        let vm = viewModel()
        toDetailsStep(vm)

        vm.onEvent(.continueClicked)
        await waitUntil("the main screen is pushed") { navigator.commandLog.count == 2 }

        let plan = try #require(store.input.plan)
        #expect(plan.mode == .quit)
        #expect(plan.baselineUnitsPerDay == 20)
        #expect(plan.currencyCode == "TRY")
        // 95 / 20 = 4.75 -> 475 minor units per cigarette
        #expect(store.input.prices.first?.unitCostMinor == 475)
        #expect(store.input.attempts.first?.startedAtMs == nowMs)
        #expect(navigator.commandLog == [.pop, .navigate(AnyNavKey(SmokingKey()))])
    }

    @Test("a second tap on start while the first write is in flight does nothing")
    func doubleTapWritesOnce() async {
        let vm = viewModel()
        toDetailsStep(vm)
        let inFlight = WriteGate()
        store.gate = inFlight

        vm.onEvent(.continueClicked)
        vm.onEvent(.continueClicked)
        await waitUntil("one write started") { store.calls == 1 }
        // Let anything the second tap would have started get its turn before asserting it did not.
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        #expect(store.calls == 1, "one write started, the second tap ignored")
        #expect(vm.state.isSaving)

        inFlight.open()
        await waitUntil("the main screen is pushed") { navigator.commandLog.count == 2 }

        #expect(store.commits == 1)
        #expect(navigator.commandLog == [.pop, .navigate(AnyNavKey(SmokingKey()))])
    }

    @Test("a refused setup becomes an error effect and leaves the wizard where it was")
    func refusedSetupLeavesTheWizard() async {
        // A plan already exists, so the use case answers `invalidInput`.
        let existing = FakeSmokingStore()
        let first = viewModel(store: existing)
        toDetailsStep(first)
        first.onEvent(.continueClicked)
        await waitUntil("the first plan is written") { navigator.commandLog.count == 2 }
        let second = viewModel(store: existing)
        toDetailsStep(second)

        second.onEvent(.continueClicked)
        await waitUntil("the refusal is reported") { !second.pendingEffects.isEmpty }

        #expect(second.pendingEffects == [.showError(.invalid)])
        #expect(second.state.step == .details)
        #expect(!second.state.isSaving)
        #expect(navigator.commandLog.count == 2, "nothing was pushed or popped by the refused setup")
        #expect(existing.commits == 1)
    }

    /// No Kotlin twin — plan Task 6 review note. A store that cannot be written answers with an
    /// error no domain rule produces; the wizard has to report it and stay put, so the More row
    /// (which reads `.notSetUp` from an unreadable store) cannot push a setup that loops.
    @Test("a storage fault becomes the generic error effect and leaves the wizard on its last step")
    func storageFaultIsReported() async {
        let broken = FakeSmokingStore()
        broken.failure = FakeStorageFault()
        let vm = viewModel(store: broken)
        toDetailsStep(vm)

        vm.onEvent(.continueClicked)
        await waitUntil("the fault is reported") { !vm.pendingEffects.isEmpty }

        #expect(vm.pendingEffects == [.showError(.generic)])
        #expect(vm.state.step == .details)
        #expect(!vm.state.isSaving, "the button is live again, so the person can retry or leave")
        #expect(navigator.commandLog.isEmpty)
        #expect(broken.input.plan == nil)
    }

    @Test("a future quit date the use case still refuses is reported as the future-date error")
    func useCaseFutureDateIsReported() async {
        let vm = viewModel()
        toDetailsStep(vm)
        // The state's own guard keeps a future date out; moving the clock back after the pick is
        // the one way the use case's check can still fire (the device clock was set back).
        vm.onEvent(.quitAtChanged(nowMs - 1000))
        clock.advanceTo(Date(timeIntervalSince1970: 1_773_133_200 - 3600))

        vm.onEvent(.continueClicked)
        await waitUntil("the refusal is reported") { !vm.pendingEffects.isEmpty }

        #expect(vm.pendingEffects == [.showError(.futureDate)])
        #expect(store.commits == 0)
    }
}
