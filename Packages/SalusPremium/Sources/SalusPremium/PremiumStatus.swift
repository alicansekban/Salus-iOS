/// Whether the user may use premium features, and why.
///
/// `gracePeriod` is still an entitled state: the store reports the entitlement as active
/// while it retries a failed renewal, so the user keeps access until the retry window ends.
/// Ported 1:1 from `PremiumStatus.kt`.
public enum PremiumStatus: Sendable, Equatable {
    case free
    case premium
    case gracePeriod
}

/// True for every state that unlocks premium features.
extension PremiumStatus {
    public var isEntitled: Bool { self != .free }
}

/// Maps the store's raw entitlement flags onto a `PremiumStatus`.
///
/// - Parameters:
///   - entitlementActive: whether the premium entitlement is currently active.
///   - hasBillingIssue: whether the store is retrying a failed renewal for it.
public func premiumStatusOf(entitlementActive: Bool, hasBillingIssue: Bool) -> PremiumStatus {
    if entitlementActive, hasBillingIssue {
        return .gracePeriod
    }
    if entitlementActive {
        return .premium
    }
    return .free
}
