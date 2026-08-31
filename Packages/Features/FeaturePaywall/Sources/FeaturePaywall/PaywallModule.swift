// Ported from `feature/paywall/src/main/kotlin/com/alicansekban/salus/feature/paywall/
// di/PaywallModule.kt`.
//
// Koin's `module { … }` is a description the container resolves at each call site; there is no
// container here (`CLAUDE.md`: "the composition root owns the singletons"), so the module is a
// value the composition root builds once and hands down. The `viewModelOf(::PaywallViewModel)`
// registration maps to `makePaywallViewModel()`, a closure that captures the three dependencies
// the composition root passes in.

import SalusPremium
import SwiftUI

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

    /// Builds the surface the store sheet attaches to — the iOS twin of Android's
    /// `ActivityPurchasesHost` (`RevenueCatPurchasesGateway.kt:23`).
    ///
    /// The concrete host is `WindowPurchaseHost`, which lives in the **app** target (it carries a
    /// `UIWindow`, and a core package must stay UI-free). The composition root fills this closure
    /// with a `WindowPurchaseHost` construction; the route only ever sees the `PurchaseHost`
    /// protocol, exactly as the sheet never learns what a purchase host is.
    public let makePurchaseHost: @MainActor () -> any PurchaseHost

    public init(
        gateway: any PurchasesGateway,
        premiumRepository: any PremiumRepository,
        paywallController: PaywallController,
        makePaywallViewModel: @escaping @MainActor () -> PaywallViewModel,
        makePurchaseHost: @escaping @MainActor () -> any PurchaseHost
    ) {
        self.gateway = gateway
        self.premiumRepository = premiumRepository
        self.paywallController = paywallController
        self.makePaywallViewModel = makePaywallViewModel
        self.makePurchaseHost = makePurchaseHost
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
    paywallController: PaywallController,
    makePurchaseHost: @escaping @MainActor () -> any PurchaseHost
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
        },
        makePurchaseHost: makePurchaseHost
    )
}

extension EnvironmentValues {
    /// How the module reaches this feature's Routes.
    ///
    /// The Route cannot read `AppCompositionRoot` itself — that type lives in the app target, which
    /// a package cannot import — so the shell injects the finished module instead. Optional because
    /// an `@Entry` needs a default and there is no honest one: a module built from nothing would be
    /// a second, silent object graph. A Route that finds nil draws its spinner, which is what a
    /// dropped injection should look like.
    @Entry public var paywallModule: PaywallModule?
}
