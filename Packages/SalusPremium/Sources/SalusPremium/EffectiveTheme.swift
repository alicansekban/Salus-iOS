import SalusModel

/// The palette that may actually be drawn for `status`, given the user's stored `selected` one.
///
/// The selection is never cleared when an entitlement lapses: a user who resubscribes finds the
/// palette they chose still waiting. So the enforcement lives here, on the read side — an
/// entitled user (premium or in the store's grace period) gets what they picked, everyone else
/// gets `PremiumTheme.classic`. Ported 1:1 from `EffectiveTheme.kt`.
public func effectivePremiumTheme(_ status: PremiumStatus, _ selected: PremiumTheme) -> PremiumTheme {
    status.isEntitled ? selected : .classic
}
