// The M8 stand-in for the `PaywallRequester` the More hub calls when a free user taps a premium
// row — **ruling 5**. The real `PaywallController` arrives with iOS-M9 (the store milestone); until
// then there is no paywall surface to show, so this no-op logs the source and does nothing, exactly
// the way `FreeOnlyMorePremiumStatus` stands in for the real entitlement on the read side.
//
// The protocol lives in `FeatureSettings` (`MoreViewModel.swift`) because the More tab is its only
// caller today; M9 lifts it into `SalusPremium` and binds a real `PaywallController` here, the same
// way it will swap `FreeOnlyMorePremiumStatus` for a real `MorePremiumStatus`. The binding change is
// the whole swap — neither `MoreViewModel` nor `MoreScreen` changes shape, which is why the
// protocol exists at all rather than a hardcoded no-op in the ViewModel.

import FeatureSettings
import os

/// `PaywallRequester` until iOS-M9 brings the real one — ruling 5.
///
/// `show(_:)` logs the source and no-ops with a TODO(M9). The source is what a future paywall would
/// key its intro copy on, so logging it now is the closest the stand-in gets to the real behaviour
/// short of drawing a sheet that does not exist yet.
@MainActor
final class NoOpPaywallRequester: PaywallRequester {
    private static let logger = Logger(subsystem: "com.alicansekban.salus", category: "paywall")

    func show(_ source: PaywallSource) {
        // TODO(M9): the real `PaywallController` shows the paywall for `source` here.
        Self.logger.debug("paywall requested for \(String(describing: source), privacy: .public) — no-op until M9")
    }
}
