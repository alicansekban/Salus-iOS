// Ported case for case from `feature/smoking/src/test/kotlin/com/alicansekban/salus/feature/
// smoking/ui/setup/SmokingSetupViewModelTest.kt`. The same rows, the same expected values; the
// Kotlin names are kept in the Swift test titles so a missing row is visible by name.
//
// Three cases have no Kotlin twin and are marked: the storage fault (plan Task 6 review note — a
// write that fails for a reason no domain rule produces must surface as an error and leave the
// wizard where it was, never loop back into itself), and the two step-bar jumps, which exist
// because iOS cannot intercept the system back button the way Android's `BackHandler` does.

import Foundation
import SalusCommon
import SalusModel
import SalusNavigation
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

@MainActor
@Suite("SmokingSetupViewModel", .timeLimit(.minutes(1)))
struct SmokingSetupViewModelTests: SetupSuite {
    let harness = SetupHarness()

    // MARK: Step flow and validation

    @Test("the wizard starts on the mode step with quit and a cigarette preselected")
    func startsOnModeStep() {
        let state = viewModel().state

        #expect(state.step == .mode)
        #expect(state.mode == .quit)
        #expect(state.product == .cigarette)
        #expect(state.currencyCode == "TRY")
        #expect(state.quitAtMs == nowMs)
    }

    @Test("the amount step does not continue without a price above zero")
    func amountStepNeedsAPrice() {
        let vm = viewModel()
        vm.onEvent(.continueClicked)
        vm.onEvent(.continueClicked)
        #expect(vm.state.step == .amount)

        vm.onEvent(.continueClicked)
        #expect(vm.state.step == .amount, "a blank price")

        vm.onEvent(.priceChanged("0"))
        vm.onEvent(.continueClicked)
        #expect(vm.state.step == .amount, "a zero price")

        vm.onEvent(.priceChanged("95"))
        #expect(vm.state.canContinue)
        vm.onEvent(.continueClicked)
        #expect(vm.state.step == .details)
    }

    @Test("a price with more decimals than the currency has is not valid")
    func tooManyDecimalsIsInvalid() {
        let vm = viewModel()
        vm.onEvent(.continueClicked)
        vm.onEvent(.continueClicked)

        vm.onEvent(.priceChanged("95.555"))

        #expect(!vm.state.canContinue)
    }

    @Test("the live summary is units per day times the unit cost, and a year of it")
    func liveSummaryIsADayAndAYear() {
        let vm = viewModel()
        vm.onEvent(.continueClicked)
        vm.onEvent(.continueClicked)

        vm.onEvent(.priceChanged("95"))

        // 20 a day at 95 / 20 = 4.75 each.
        #expect(vm.state.summary == .daily(dailyMinor: 9500, yearlyMinor: 3_467_500))
    }

    @Test("the pack price is divided by the pack size, rounded half up, into the unit cost")
    func packPriceRoundsHalfUp() {
        let vm = viewModel()
        vm.onEvent(.continueClicked)
        vm.onEvent(.continueClicked)
        vm.onEvent(.priceChanged("100"))
        vm.onEvent(.unitsPerPackChanged(30))

        // 10 000 / 30 = 333.33.
        #expect(vm.state.unitCostMinor == 333)

        vm.onEvent(.priceChanged("100.05"))
        // 10 005 / 30 = 333.5 rounds up.
        #expect(vm.state.unitCostMinor == 334)
    }

    // MARK: Vape

    @Test("a vape is priced weekly and the summary is the week and the year")
    func vapeSummaryIsAWeekAndAYear() {
        let vm = viewModel()
        vm.onEvent(.productSelected(.vape))
        vm.onEvent(.continueClicked)
        vm.onEvent(.continueClicked)

        vm.onEvent(.priceChanged("400"))

        #expect(vm.state.summary == .weekly(weeklyMinor: 40000, yearlyMinor: 2_080_000))
    }

    @Test("a vape stores the weekly spend over seven rounded half up and a baseline of one")
    func vapeStoresWeeklyOverSeven() async {
        let vm = viewModel()
        vm.onEvent(.productSelected(.vape))
        vm.onEvent(.continueClicked) // mode -> product
        vm.onEvent(.continueClicked) // product -> amount; VAPE has no per-day or per-pack question
        vm.onEvent(.priceChanged("10"))
        vm.onEvent(.continueClicked) // amount -> details
        vm.onEvent(.continueClicked) // start
        await waitUntil("the plan is written") { store.commits == 1 }

        let input = store.input
        #expect(input.plan?.baselineUnitsPerDay == 1)
        #expect(input.plan?.productType == .vape)
        // 1 000 / 7 = 142.857
        #expect(input.prices.first?.unitCostMinor == 143)
    }

    @Test("a price typed for a pack is dropped when the product becomes a vape, and kept between packs")
    func priceFollowsTheProductKind() {
        let vm = viewModel()
        vm.onEvent(.priceChanged("95"))

        vm.onEvent(.productSelected(.rolled))
        #expect(vm.state.priceText == "95")

        vm.onEvent(.productSelected(.vape))
        #expect(vm.state.priceText.isEmpty)

        vm.onEvent(.priceChanged("400"))
        vm.onEvent(.productSelected(.cigarette))
        #expect(vm.state.priceText.isEmpty)
    }

    @Test("the quick-add chips raise the weekly spend by whole currency units")
    func quickAddRaisesTheWeeklySpend() {
        let vm = viewModel()
        vm.onEvent(.productSelected(.vape))
        vm.onEvent(.continueClicked)
        vm.onEvent(.continueClicked)

        vm.onEvent(.priceChanged("100"))
        vm.onEvent(.priceQuickAdded(wholeUnits: 50))
        vm.onEvent(.priceQuickAdded(wholeUnits: 100))

        #expect(vm.state.priceMinor == 25000)
    }

    // MARK: Reduce limit

    @Test("the suggested limit is eighty percent of the baseline rounded down and never below one")
    func suggestedLimitTable() {
        let vm = viewModel()
        vm.onEvent(.modeSelected(.reduce))
        let cases: [(baseline: Int, expected: Int)] = [(20, 16), (7, 5), (3, 2), (2, 1), (1, 1)]

        for row in cases {
            vm.onEvent(.unitsPerDayChanged(row.baseline))
            #expect(vm.state.suggestedLimit == row.expected, "baseline \(row.baseline)")
            #expect(vm.state.dailyLimit == row.expected, "baseline \(row.baseline)")
        }
    }

    @Test("a reduce setup writes the suggested limit unless the person picked another")
    func reduceWritesTheSuggestedLimit() async {
        let vm = viewModel()
        vm.onEvent(.modeSelected(.reduce))
        vm.onEvent(.continueClicked)
        vm.onEvent(.unitsPerDayChanged(15))
        vm.onEvent(.continueClicked)
        vm.onEvent(.priceChanged("95"))
        vm.onEvent(.continueClicked)
        // 80 % of 15 = 12
        #expect(vm.state.dailyLimit == 12)
        vm.onEvent(.continueClicked)
        await waitUntil("the plan is written") { store.commits == 1 }

        let input = store.input
        #expect(input.plan?.mode == .reduce)
        #expect(input.plan?.dailyLimit == 12)
        #expect(input.plan?.baselineUnitsPerDay == 15)
        #expect(input.attempts.isEmpty, "REDUCE opens no quit attempt")
    }

    @Test("a limit the person chose survives a later change of the baseline")
    func chosenLimitSurvivesABaselineChange() {
        let vm = viewModel()
        vm.onEvent(.modeSelected(.reduce))
        vm.onEvent(.dailyLimitChanged(9))

        vm.onEvent(.unitsPerDayChanged(30))

        #expect(vm.state.dailyLimit == 9)
    }

    @Test("a vape's suggested limit comes from its stored baseline of one, not the hidden per-day count")
    func vapeSuggestionUsesTheStoredBaseline() {
        let vm = viewModel()
        vm.onEvent(.modeSelected(.reduce))
        vm.onEvent(.productSelected(.vape))

        // The per-day stepper is never shown for a vape, so its default of 20 must not leak in.
        #expect(vm.state.suggestedLimit == 1)
        #expect(vm.state.dailyLimit == 1)
    }

    @Test("a vape reduce setup writes a limit of one by default and the picked one when changed")
    func vapeReduceWritesTheLimit() async {
        func setUpVapeReduce(_ vm: SmokingSetupViewModel, store: FakeSmokingStore, picked: Int?) async {
            vm.onEvent(.modeSelected(.reduce))
            vm.onEvent(.productSelected(.vape))
            vm.onEvent(.continueClicked)
            vm.onEvent(.continueClicked)
            vm.onEvent(.priceChanged("400"))
            vm.onEvent(.continueClicked)
            if let picked {
                vm.onEvent(.dailyLimitChanged(picked))
            }
            vm.onEvent(.continueClicked)
            await waitUntil("the plan is written") { store.commits == 1 }
        }

        await setUpVapeReduce(viewModel(), store: store, picked: nil)
        #expect(store.input.plan?.baselineUnitsPerDay == 1)
        #expect(store.input.plan?.dailyLimit == 1)

        let other = FakeSmokingStore()
        await setUpVapeReduce(viewModel(store: other), store: other, picked: 3)
        #expect(other.input.plan?.baselineUnitsPerDay == 1)
        #expect(other.input.plan?.dailyLimit == 3)
    }

    // MARK: Step bar (no Kotlin twin)

    @Test("a finished step can be reopened from the step bar; the current and later steps cannot")
    func stepBarJumpsBackOnly() {
        let vm = viewModel()
        toDetailsStep(vm)
        #expect(vm.state.step == .details)

        vm.onEvent(.stepSelected(.product))
        #expect(vm.state.step == .product)

        vm.onEvent(.stepSelected(.details))
        #expect(vm.state.step == .product, "a step not yet reached stays closed")

        vm.onEvent(.stepSelected(.product))
        #expect(vm.state.step == .product)
    }

    @Test("the step bar does nothing while the write is in flight")
    func stepBarIsInertWhileSaving() async {
        let vm = viewModel()
        toDetailsStep(vm)
        store.gate = WriteGate()

        vm.onEvent(.continueClicked)
        await waitUntil("one write started") { store.calls == 1 }
        vm.onEvent(.stepSelected(.mode))

        #expect(vm.state.step == .details)
        store.gate?.open()
    }
}
