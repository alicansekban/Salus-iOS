// Ported from `feature/paywall/src/main/kotlin/com/alicansekban/salus/feature/paywall/
// di/PaywallModule.kt`.
//
// Koin's `module { … }` is a description the container resolves at each call site; there is no
// container here (`CLAUDE.md`: "the composition root owns the singletons"), so the module is a
// value the composition root builds once and hands down. The `viewModelOf(::PaywallViewModel)`
// registration maps to `makePaywallViewModel()`, a closure that captures the three dependencies
// the composition root passes in.

import SalusPremium

/// Everything the paywall's ViewModel needs, built by the composition root (`PaywallModule.kt`).
///
/// `@MainActor` because the ViewModel it makes is: the factory is called from a view's `.task`,
/// which already runs there.
@MainActor
public struct PaywallModule {
    /// Koin's `single<PurchasesGateway>` — the store seam.
    public let gateway: any PurchasesGateway

    /// Koin's `single<PremiumRepository>` — the entitlement source of truth.
    public let premiumRepository: any PremiumRepository

    /// Koin's `single<PaywallController>` — the single gate every feature opens the paywall with.
    public let paywallController: PaywallController

    /// Koin's `viewModelOf(::PaywallViewModel)` (`PaywallModule.kt:11`).
    public let makePaywallViewModel: @MainActor () -> PaywallViewModel

    public init(
        gateway: any PurchasesGateway,
        premiumRepository: any PremiumRepository,
        paywallController: PaywallController,
        makePaywallViewModel: @escaping @MainActor () -> PaywallViewModel
    ) {
        self.gateway = gateway
        self.premiumRepository = premiumRepository
        self.paywallController = paywallController
        self.makePaywallViewModel = makePaywallViewModel
    }
}

/// Builds the feature's graph — the twin of `val paywallModule = module { … }`.
///
/// Every dependency is passed in and none is reached for, so a second graph (a test, a preview) is
/// a second call rather than a mutated global.
@MainActor
public func makePaywallModule(
    gateway: any PurchasesGateway,
    premiumRepository: any PremiumRepository,
    paywallController: PaywallController
) -> PaywallModule {
    PaywallModule(
        gateway: gateway,
        premiumRepository: premiumRepository,
        paywallController: paywallController,
        makePaywallViewModel: {
            PaywallViewModel(
                gateway: gateway,
                premiumRepository: premiumRepository,
                paywallController: paywallController
            )
        }
    )
}
