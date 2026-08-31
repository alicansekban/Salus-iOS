// Ported 1:1 from `feature/paywall/src/main/kotlin/com/alicansekban/salus/feature/paywall/
// ui/PaywallViewModel.kt` (149 lines).
//
// The Android `viewModelScope.launch { … }` becomes a `Task` owned by the instance, and the
// `MutableStateFlow` becomes the `@Observable` `state` property, read directly by tests just as
// Android reads `state.value`. The `observeSource()` collection runs from `init` to `deinit`
// because `@Observable` has no subscription-count hook — the same shape `VitalsViewModel` uses.

import Foundation
import Observation
import SalusPremium

/// Drives the paywall: it loads the store's plans, runs a purchase or a restore, and closes
/// itself through `PaywallController` — the same gate every other feature opens it with.
///
/// It never writes the entitlement itself. A finished purchase only asks `PremiumRepository` to
/// re-read the store, so the store stays the single source of truth for what is unlocked.
///
/// The controller is also where the paywall learns *why* it was opened: the open request's
/// `PaywallSource` becomes the sheet's headline.
@MainActor
@Observable
public final class PaywallViewModel {
    /// What the screen draws — the twin of Android's `state: StateFlow<PaywallUiState>`.
    public private(set) var state = PaywallUiState()

    private let gateway: any PurchasesGateway
    private let premiumRepository: any PremiumRepository
    private let paywallController: PaywallController

    public init(
        gateway: any PurchasesGateway,
        premiumRepository: any PremiumRepository,
        paywallController: PaywallController
    ) {
        self.gateway = gateway
        self.premiumRepository = premiumRepository
        self.paywallController = paywallController
        loadOffering()
        observeSource()
    }

    /// Keeps the headline on whatever the user was doing when the paywall opened.
    ///
    /// Only a non-nil request is taken: closing the paywall publishes nil, and the sheet is still
    /// on screen animating out — rewriting the headline mid-exit would be visible. The next open
    /// overwrites it before anything is drawn again.
    ///
    /// `PaywallController.request` is an `@Observable` property, not a Flow, so the Android
    /// `collect { … }` is spelled with `withObservationTracking`, which fires once per change and
    /// re-registers itself — the same shape `VitalsViewModel.trackPendingDeletes` uses. The current
    /// request is applied up front because `withObservationTracking` only fires on a *change* after
    /// registration, whereas the StateFlow emits its current value on subscription.
    private func observeSource() {
        if let request = paywallController.request {
            state.source = request.source
        }
        withObservationTracking {
            _ = paywallController.request
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let request = paywallController.request {
                    state.source = request.source
                }
                observeSource()
            }
        }
    }

    public func onEvent(_ event: PaywallEvent) {
        switch event {
        case let .planSelected(packageId):
            state.selectedPackageId = packageId
            state.error = nil

        case .reload:
            reload()

        case let .purchaseClicked(host):
            purchase(host)

        case .restoreClicked:
            restore()

        case .dismissClicked:
            paywallController.dismiss()
        }
    }

    /// What one opening of the sheet resets: the last open's failure is cleared, and an offering
    /// that never arrived is asked for again. Plans already in hand are kept — the sheet reopens
    /// instantly and the store is not re-hit on every rotation.
    private func reload() {
        state.error = nil
        if state.plans.isEmpty, !state.isLoading {
            loadOffering()
        }
    }

    private func loadOffering() {
        // Retry re-enters here, so the spinner has to come back with it.
        state.isLoading = true
        state.error = nil
        Task { [weak self] in
            guard let self else { return }
            // No plans is the same dead end as no offering: there is nothing to sell, and the
            // sheet says so instead of showing an empty list with a CTA that cannot fire.
            let plans = await gateway.currentOffering()?.plans ?? []
            if plans.isEmpty {
                state.isLoading = false
                state.error = .offeringUnavailable
                return
            }
            // The annual plan is the one we want bought, so it starts selected; any other ordering
            // the store sends still gets a valid selection.
            let preselected = plans.first { $0.period == .annual } ?? plans[0]
            state.isLoading = false
            state.plans = plans
            state.selectedPackageId = preselected.packageId
            state.error = nil
        }
    }

    private func purchase(_ host: PurchaseHost) {
        guard let packageId = state.selectedPackageId else { return }
        // The store sheet is already up; a second tap must not open a second one.
        if state.isPurchasing {
            return
        }

        state.isPurchasing = true
        state.error = nil
        Task { [weak self] in
            guard let self else { return }
            switch await gateway.purchase(host: host, packageId: packageId) {
            case .success:
                await premiumRepository.refresh()
                state.isPurchasing = false
                paywallController.dismiss()

            // Backing out of the store sheet is a choice, not a failure: the paywall stays open
            // and shows no error.
            case .cancelled:
                state.isPurchasing = false

            case .error:
                state.isPurchasing = false
                state.error = .purchaseFailed
            }
        }
    }

    private func restore() {
        // A restore is as busy as a purchase, and shares the flag: the CTA and the restore button
        // are both disabled on it, so neither call can be fired twice.
        if state.isPurchasing {
            return
        }

        state.isPurchasing = true
        state.error = nil
        Task { [weak self] in
            guard let self else { return }
            let snapshot = await gateway.restore()
            // Refresh either way: the restore may have changed what the store reports even when it
            // found no premium entitlement for this account.
            await premiumRepository.refresh()
            state.isPurchasing = false
            if snapshot.entitlementActive {
                paywallController.dismiss()
            } else {
                state.error = .restoreNoEntitlement
            }
        }
    }
}
