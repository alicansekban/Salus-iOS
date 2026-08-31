// Ported 1:1 from `feature/paywall/src/test/kotlin/com/alicansekban/salus/feature/paywall/
// ui/PaywallViewModelTest.kt` (21 cases). Case names are the Kotlin backtick names in camelCase.
//
// Two mechanical differences from the Kotlin, both already settled elsewhere in this port:
// `advanceUntilIdle()` becomes `waitUntil` (Swift Testing has no virtual scheduler), and the
// `CompletableDeferred` concurrency gates become the `Gate` in `Fakes.swift`. The Android
// `PremiumRepositoryImpl` is replaced by `FakePremiumRepository`, which mirrors its refresh
// behaviour so the entitlement assertions read the same.

import SalusPremium
import Testing

@testable import FeaturePaywall

@Suite("PaywallViewModel (Android parity)")
@MainActor
struct PaywallViewModelTests {
    /// `PaywallViewModelTest.kt:104-111` — the gateway is always the fake; the controller defaults
    /// to a fresh one and the repository to a fake over the same gateway.
    private func viewModel(
        gateway: FakePurchasesGateway,
        controller: PaywallController = PaywallController()
    ) -> PaywallViewModel {
        PaywallViewModel(
            gateway: gateway,
            premiumRepository: FakePremiumRepository(gateway: gateway),
            paywallController: controller
        )
    }

    @Test("init preselects the annual plan")
    func initPreselectsTheAnnualPlan() async {
        let gateway = FakePurchasesGateway()
        let viewModel = viewModel(gateway: gateway)

        await waitUntil("the offering loads") { !viewModel.state.isLoading }

        let state = viewModel.state
        #expect(!state.isLoading)
        #expect(state.plans == [monthly, sixMonth, annual])
        #expect(state.selectedPackageId == "annual")
        #expect(state.error == nil)
    }

    @Test("init falls back to the first plan when there is no annual one")
    func initFallsBackToTheFirstPlanWhenThereIsNoAnnualOne() async {
        let gateway = FakePurchasesGateway(offering: PaywallOffering(plans: [sixMonth, monthly]))
        let viewModel = viewModel(gateway: gateway)

        await waitUntil("the offering loads") { !viewModel.state.isLoading }

        #expect(viewModel.state.selectedPackageId == "six_month")
    }

    @Test("a missing offering surfaces offeringUnavailable")
    func aMissingOfferingSurfacesOfferingUnavailable() async {
        let gateway = FakePurchasesGateway(offering: nil)
        let viewModel = viewModel(gateway: gateway)

        await waitUntil("the offering fails") { viewModel.state.error == .offeringUnavailable }

        let state = viewModel.state
        #expect(!state.isLoading)
        #expect(state.plans.isEmpty)
        #expect(state.selectedPackageId == nil)
        #expect(state.error == .offeringUnavailable)
    }

    @Test("a successful purchase refreshes the entitlement and dismisses the paywall")
    func aSuccessfulPurchaseRefreshesTheEntitlementAndDismissesThePaywall() async {
        let gateway = FakePurchasesGateway(purchaseOutcome: .success)
        let controller = PaywallController()
        controller.show(.settings)
        let repository = FakePremiumRepository(gateway: gateway)
        let viewModel = PaywallViewModel(
            gateway: gateway,
            premiumRepository: repository,
            paywallController: controller
        )
        await waitUntil("the offering loads") { !viewModel.state.isLoading }

        viewModel.onEvent(.purchaseClicked(FakePurchaseHost()))
        await waitUntil("the purchase finishes") { !viewModel.state.isPurchasing }

        #expect(gateway.purchasedPackageIds == ["annual"])
        #expect(repository.currentStatus == .premium)
        #expect(controller.request == nil)
        #expect(!viewModel.state.isPurchasing)
        #expect(viewModel.state.error == nil)
    }

    @Test("a cancelled purchase leaves the paywall open without an error")
    func aCancelledPurchaseLeavesThePaywallOpenWithoutAnError() async {
        let gateway = FakePurchasesGateway(purchaseOutcome: .cancelled)
        let controller = PaywallController()
        controller.show(.settings)
        let viewModel = viewModel(gateway: gateway, controller: controller)
        await waitUntil("the offering loads") { !viewModel.state.isLoading }

        viewModel.onEvent(.purchaseClicked(FakePurchaseHost()))
        await waitUntil("the purchase finishes") { !viewModel.state.isPurchasing }

        #expect(!viewModel.state.isPurchasing)
        #expect(viewModel.state.error == nil)
        #expect(controller.request != nil)
    }

    @Test("a failed purchase surfaces purchaseFailed")
    func aFailedPurchaseSurfacesPurchaseFailed() async {
        let gateway = FakePurchasesGateway(purchaseOutcome: .error("card declined"))
        let controller = PaywallController()
        controller.show(.settings)
        let viewModel = viewModel(gateway: gateway, controller: controller)
        await waitUntil("the offering loads") { !viewModel.state.isLoading }

        viewModel.onEvent(.purchaseClicked(FakePurchaseHost()))
        await waitUntil("the purchase finishes") { !viewModel.state.isPurchasing }

        #expect(!viewModel.state.isPurchasing)
        #expect(viewModel.state.error == .purchaseFailed)
        #expect(controller.request != nil)
    }

    @Test("a second purchase click is ignored while one is in flight")
    func aSecondPurchaseClickIsIgnoredWhileOneIsInFlight() async {
        let gate = Gate()
        let gateway = FakePurchasesGateway()
        gateway.purchaseGate = gate
        let viewModel = viewModel(gateway: gateway)
        await waitUntil("the offering loads") { !viewModel.state.isLoading }

        viewModel.onEvent(.purchaseClicked(FakePurchaseHost()))
        await waitUntil("the purchase is in flight") { viewModel.state.isPurchasing }

        viewModel.onEvent(.purchaseClicked(FakePurchaseHost()))
        await waitUntil("the second click settles") { gateway.purchaseCalls == 1 }
        #expect(gateway.purchaseCalls == 1)

        gate.open()
        await waitUntil("the purchase finishes") { !viewModel.state.isPurchasing }
    }

    @Test("a restore that finds an entitlement refreshes and dismisses")
    func aRestoreThatFindsAnEntitlementRefreshesAndDismisses() async {
        let gateway = FakePurchasesGateway(
            restoreSnapshot: CustomerSnapshot(entitlementActive: true, hasBillingIssue: false)
        )
        let controller = PaywallController()
        controller.show(.settings)
        let repository = FakePremiumRepository(gateway: gateway)
        let viewModel = PaywallViewModel(
            gateway: gateway,
            premiumRepository: repository,
            paywallController: controller
        )
        await waitUntil("the offering loads") { !viewModel.state.isLoading }

        viewModel.onEvent(.restoreClicked)
        await waitUntil("the restore finishes") { !viewModel.state.isPurchasing }

        #expect(gateway.restoreCalls == 1)
        #expect(repository.currentStatus == .premium)
        #expect(controller.request == nil)
        #expect(viewModel.state.error == nil)
    }

    @Test("a restore that finds nothing surfaces restoreNoEntitlement and still refreshes")
    func aRestoreThatFindsNothingSurfacesRestoreNoEntitlementAndStillRefreshes() async {
        let gateway = FakePurchasesGateway(
            customer: CustomerSnapshot(entitlementActive: false, hasBillingIssue: false),
            restoreSnapshot: CustomerSnapshot(entitlementActive: false, hasBillingIssue: false)
        )
        let controller = PaywallController()
        controller.show(.settings)
        let viewModel = viewModel(gateway: gateway, controller: controller)
        await waitUntil("the offering loads") { !viewModel.state.isLoading }
        let refreshesBefore = gateway.currentCustomerCalls

        viewModel.onEvent(.restoreClicked)
        await waitUntil("the restore finishes") { !viewModel.state.isPurchasing }

        #expect(viewModel.state.error == .restoreNoEntitlement)
        #expect(gateway.currentCustomerCalls == refreshesBefore + 1)
        #expect(controller.request != nil)
    }

    @Test("selecting a plan clears the error")
    func selectingAPlanClearsTheError() async {
        let gateway = FakePurchasesGateway(purchaseOutcome: .error("card declined"))
        let viewModel = viewModel(gateway: gateway)
        await waitUntil("the offering loads") { !viewModel.state.isLoading }
        viewModel.onEvent(.purchaseClicked(FakePurchaseHost()))
        await waitUntil("the purchase fails") { viewModel.state.error == .purchaseFailed }

        viewModel.onEvent(.planSelected("monthly"))

        #expect(viewModel.state.selectedPackageId == "monthly")
        #expect(viewModel.state.error == nil)
    }

    @Test("a restore blocks a second restore while one is in flight")
    func aRestoreBlocksASecondRestoreWhileOneIsInFlight() async {
        let gate = Gate()
        let gateway = FakePurchasesGateway()
        gateway.restoreGate = gate
        let viewModel = viewModel(gateway: gateway)
        await waitUntil("the offering loads") { !viewModel.state.isLoading }

        viewModel.onEvent(.restoreClicked)
        await waitUntil("the restore is in flight") { viewModel.state.isPurchasing }

        viewModel.onEvent(.restoreClicked)
        await waitUntil("the second restore settles") { gateway.restoreCalls == 1 }
        #expect(gateway.restoreCalls == 1)

        gate.open()
        await waitUntil("the restore finishes") { !viewModel.state.isPurchasing }
    }

    @Test("a restore in flight blocks a purchase click")
    func aRestoreInFlightBlocksAPurchaseClick() async {
        let gate = Gate()
        let gateway = FakePurchasesGateway()
        gateway.restoreGate = gate
        let viewModel = viewModel(gateway: gateway)
        await waitUntil("the offering loads") { !viewModel.state.isLoading }

        viewModel.onEvent(.restoreClicked)
        await waitUntil("the restore is in flight") { viewModel.state.isPurchasing }
        viewModel.onEvent(.purchaseClicked(FakePurchaseHost()))
        await waitUntil("the purchase click settles") { gateway.purchaseCalls == 0 }

        #expect(gateway.purchaseCalls == 0)
        gate.open()
        await waitUntil("the restore finishes") { !viewModel.state.isPurchasing }
    }

    @Test("a restore clears the error it starts with")
    func aRestoreClearsTheErrorItStartsWith() async {
        let gate = Gate()
        let gateway = FakePurchasesGateway(purchaseOutcome: .error("card declined"))
        let viewModel = viewModel(gateway: gateway)
        await waitUntil("the offering loads") { !viewModel.state.isLoading }
        viewModel.onEvent(.purchaseClicked(FakePurchaseHost()))
        await waitUntil("the purchase fails") { viewModel.state.error == .purchaseFailed }

        gateway.restoreGate = gate
        viewModel.onEvent(.restoreClicked)
        await waitUntil("the restore clears the error") { viewModel.state.error == nil }

        gate.open()
        await waitUntil("the restore finishes") { !viewModel.state.isPurchasing }
        #expect(viewModel.state.error == .restoreNoEntitlement)
    }

    @Test("reload refetches an offering that never arrived")
    func reloadRefetchesAnOfferingThatNeverArrived() async {
        let gateway = FakePurchasesGateway(offering: nil)
        let viewModel = viewModel(gateway: gateway)
        await waitUntil("the offering fails") { viewModel.state.error == .offeringUnavailable }

        gateway.offering = PaywallOffering(plans: [monthly, sixMonth, annual])
        viewModel.onEvent(.reload)
        await waitUntil("the offering reloads") { !viewModel.state.isLoading }

        let state = viewModel.state
        #expect(!state.isLoading)
        #expect(state.plans == [monthly, sixMonth, annual])
        #expect(state.selectedPackageId == "annual")
        #expect(state.error == nil)
    }

    @Test("reload clears the last open's failure but keeps the plans it has")
    func reloadClearsTheLastOpenSFailureButKeepsThePlansItHas() async {
        let gateway = FakePurchasesGateway(purchaseOutcome: .error("card declined"))
        let viewModel = viewModel(gateway: gateway)
        await waitUntil("the offering loads") { !viewModel.state.isLoading }
        viewModel.onEvent(.planSelected("monthly"))
        viewModel.onEvent(.purchaseClicked(FakePurchaseHost()))
        await waitUntil("the purchase fails") { viewModel.state.error == .purchaseFailed }
        let offeringCallsBefore = gateway.offeringCalls

        viewModel.onEvent(.reload)
        await waitUntil("the reload clears the error") { viewModel.state.error == nil }

        let state = viewModel.state
        #expect(state.error == nil)
        #expect(state.plans == [monthly, sixMonth, annual])
        #expect(state.selectedPackageId == "monthly")
        #expect(gateway.offeringCalls == offeringCallsBefore)
    }

    @Test("dismiss closes the paywall")
    func dismissClosesThePaywall() async {
        let gateway = FakePurchasesGateway()
        let controller = PaywallController()
        controller.show(.settings)
        let viewModel = viewModel(gateway: gateway, controller: controller)
        await waitUntil("the offering loads") { !viewModel.state.isLoading }

        viewModel.onEvent(.dismissClicked)

        #expect(controller.request == nil)
    }

    // MARK: - Contextual headline (spec section 4)

    @Test("state carries the source the paywall was opened from")
    func stateCarriesTheSourceThePaywallWasOpenedFrom() async {
        let controller = PaywallController()
        controller.show(.trends)
        let viewModel = viewModel(gateway: FakePurchasesGateway(), controller: controller)

        await waitUntil("the source is applied") { viewModel.state.source == .trends }

        #expect(viewModel.state.source == .trends)
    }

    @Test("reopening from another feature replaces the source")
    func reopeningFromAnotherFeatureReplacesTheSource() async {
        let controller = PaywallController()
        controller.show(.themes)
        let viewModel = viewModel(gateway: FakePurchasesGateway(), controller: controller)
        await waitUntil("the source is applied") { viewModel.state.source == .themes }

        viewModel.onEvent(.dismissClicked)
        controller.show(.backup)
        await waitUntil("the source is replaced") { viewModel.state.source == .backup }

        #expect(viewModel.state.source == .backup)
    }

    /// The sheet is still on screen animating out; rewriting its headline would be visible.
    @Test("dismissing keeps the last source instead of resetting the headline")
    func dismissingKeepsTheLastSourceInsteadOfResettingTheHeadline() async {
        let controller = PaywallController()
        controller.show(.doctorReport)
        let viewModel = viewModel(gateway: FakePurchasesGateway(), controller: controller)
        await waitUntil("the source is applied") { viewModel.state.source == .doctorReport }

        viewModel.onEvent(.dismissClicked)
        await waitUntil("the dismiss settles") { controller.request == nil }

        #expect(viewModel.state.source == .doctorReport)
    }

    @Test("the two non-feature entry points keep the generic title")
    func theTwoNonFeatureEntryPointsKeepTheGenericTitle() {
        #expect(headlineKey(for: .settings) == headlineKey(for: .onboarding))
    }

    @Test("every feature source gets a headline of its own")
    func everyFeatureSourceGetsAHeadlineOfItsOwn() {
        let featureSources: [PaywallSource] = [.themes, .trends, .aiSummary, .doctorReport, .backup]
        let generic = headlineKey(for: .settings)

        let headlines = featureSources.map(headlineKey(for:))

        #expect(!headlines.contains(generic))
        #expect(headlines.count == Set(headlines).count)
    }
}
