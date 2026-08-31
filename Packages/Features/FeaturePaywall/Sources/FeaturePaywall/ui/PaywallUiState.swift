// Ported 1:1 from `feature/paywall/src/main/kotlin/com/alicansekban/salus/feature/paywall/
// ui/PaywallUiState.kt` (71 lines). UDF file naming follows the Android rule: `<Screen>UiState.kt`
// holds UiState/Event/Error — never `<X>Contract.kt`.

import SalusPremium

/// What the paywall shows.
///
/// `error` is the only failure channel: a purchase the user backed out of is not a failure and
/// leaves this `nil`, so the sheet says nothing and stays open.
///
/// `source` is what the user was doing when the paywall opened; it only picks the headline.
/// It defaults to `.settings` — the generic pitch — so a sheet that somehow renders before the
/// controller has published a request still reads correctly.
public struct PaywallUiState: Equatable {
    public var isLoading = true
    public var plans: [PremiumPlan] = []
    public var selectedPackageId: String?
    public var isPurchasing = false
    public var error: PaywallError?
    public var source: PaywallSource = .settings

    public init() {}
}

/// The failures the paywall can show, each mapped to one message by the UI.
public enum PaywallError: Equatable, Sendable {
    case offeringUnavailable
    case purchaseFailed
    case restoreNoEntitlement
}

/// The events the paywall's UI sends the ViewModel.
public enum PaywallEvent: Sendable {
    case planSelected(String)

    /// Sent every time the sheet opens, and by the retry button when there is nothing to sell.
    ///
    /// The ViewModel is retained by the shell, so it outlives the sheet: without this the failure
    /// of one open would still be on screen at the next one, and an offering that failed to load
    /// would never be asked for again.
    case reload

    /// `host` is the surface the store sheet attaches to; only the UI layer can supply it.
    case purchaseClicked(PurchaseHost)
    case restoreClicked
    case dismissClicked
}

/// The headline for a paywall opened from `source` (spec section 4: a locked feature opens the
/// paywall with a contextual headline).
///
/// The two entry points that are *about* premium rather than about a feature — the settings row
/// and the post-onboarding introduction — keep the generic product title; there is no single
/// feature to name in either case.
///
/// The mapping itself lives in `PaywallStrings.headlineKey(for:)` (T1); this is the `headlineResFor`
/// twin's call site, kept as a thin delegate so the UiState file owns the interface the tests
/// exercise.
func headlineKey(for source: PaywallSource) -> String {
    PaywallStrings.headlineKey(for: source)
}
