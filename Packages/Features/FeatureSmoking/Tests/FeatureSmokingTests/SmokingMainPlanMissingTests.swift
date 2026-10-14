// Twin of the two plan-missing cases in `SmokingMainViewModelTest.kt` (Android 35f5836): a milestone
// notification tapped after "Takibi sıfırla" opens Main over a reset app, and Main swaps itself for
// the setup (pop, then push) instead of drawing an empty body. Its own file so it stays clear of the
// other Main suites.

import Foundation
import SalusCommon
import SalusNavigation
import SalusSmoking
import SalusTesting
import SalusUI
import Testing

@testable import FeatureSmoking

@MainActor
@Suite("SmokingMainViewModel — plan missing", .timeLimit(.minutes(1)))
struct SmokingMainPlanMissingTests {
    let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_773_133_200))
    let navigator = FakeNavigator()
    let ids = CountingIds()
    let snackbar = SalusSnackbarController()

    private func viewModel(over input: SmokingInput) -> SmokingMainViewModel {
        makeMainViewModel(
            store: FakeSmokingStore(initial: input),
            clock: clock,
            ids: ids,
            snackbar: snackbar,
            navigator: navigator
        )
    }

    private var noPlan: SmokingInput {
        SmokingInput(plan: nil, prices: [], attempts: [], events: [], goal: nil)
    }

    private func settle() async {
        // The recorder drains `Navigator.commands` one hop behind the ViewModel.
        for _ in 0 ..< 20 {
            await Task.yield()
        }
    }

    @Test("a missing plan replaces the screen with the setup: pop, then push")
    func missingPlanReplacesWithSetup() async {
        let vm = viewModel(over: noPlan)
        await waitUntil("the first snapshot") { vm.state.snapshot != nil }
        #expect(vm.state.snapshot == .notSetUp)

        vm.onEvent(.planMissing)
        await waitUntil("two commands") { navigator.commandLog.count == 2 }

        #expect(navigator.commandLog == [.pop, .navigate(AnyNavKey(SmokingSetupKey()))])
    }

    @Test("the swap happens once, however often the route reports the missing plan")
    func swapsOnce() async {
        let vm = viewModel(over: noPlan)
        await waitUntil("the first snapshot") { vm.state.snapshot != nil }

        vm.onEvent(.planMissing)
        vm.onEvent(.planMissing)
        vm.onEvent(.planMissing)
        await waitUntil("two commands") { navigator.commandLog.count == 2 }
        await settle()

        #expect(navigator.commandLog == [.pop, .navigate(AnyNavKey(SmokingSetupKey()))])
    }

    @Test("the signal is ignored before the first snapshot")
    func ignoredBeforeTheFirstSnapshot() async {
        let vm = viewModel(over: noPlan)
        #expect(vm.state.snapshot == nil)

        vm.onEvent(.planMissing)
        await settle()

        #expect(navigator.commandLog.isEmpty)
    }

    @Test("the signal is ignored while a plan exists")
    func ignoredWhilePlanExists() async {
        let harness = MainHarness()
        let vm = await harness.subscribedViewModel()

        vm.onEvent(.planMissing)
        await settle()

        #expect(harness.navigator.commandLog.isEmpty)
    }
}
