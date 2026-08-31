import Foundation

/// The store's raw view of the customer: the two flags `premiumStatusOf` needs.
/// Ported 1:1 from `PaywallModels.kt`.
public struct CustomerSnapshot: Sendable, Equatable {
    public let entitlementActive: Bool
    public let hasBillingIssue: Bool

    public init(entitlementActive: Bool, hasBillingIssue: Bool) {
        self.entitlementActive = entitlementActive
        self.hasBillingIssue = hasBillingIssue
    }
}

/// The billing periods the paywall offers.
public enum PlanPeriod: Sendable, Equatable, CaseIterable {
    case monthly
    case sixMonth
    case annual
}

/// One purchasable plan on the paywall.
///
/// - Parameters:
///   - packageId: the store package identifier the purchase call takes.
///   - priceFormatted: the store's own localized price, e.g. "₺49,99" — never formatted by us.
///   - monthlyEquivalent: the per-month price of a multi-month plan, `nil` for `PlanPeriod.monthly`.
public struct PremiumPlan: Sendable, Equatable {
    public let packageId: String
    public let period: PlanPeriod
    public let priceFormatted: String
    public let monthlyEquivalent: String?
    public let hasFreeTrial: Bool

    public init(
        packageId: String,
        period: PlanPeriod,
        priceFormatted: String,
        monthlyEquivalent: String?,
        hasFreeTrial: Bool
    ) {
        self.packageId = packageId
        self.period = period
        self.priceFormatted = priceFormatted
        self.monthlyEquivalent = monthlyEquivalent
        self.hasFreeTrial = hasFreeTrial
    }
}

/// The set of plans the paywall shows, in display order.
public struct PaywallOffering: Sendable, Equatable {
    public let plans: [PremiumPlan]

    public init(plans: [PremiumPlan]) {
        self.plans = plans
    }
}

/// Formats what a multi-month plan costs per month, so the paywall can compare plans.
///
/// Returns `nil` for `PlanPeriod.monthly` (there is nothing to divide) and for a
/// `currencyCode` the platform does not know.
///
/// - Parameter amountMicros: the plan's total price in micros, as the store reports it.
public func monthlyEquivalentOf(
    amountMicros: Int64,
    currencyCode: String,
    period: PlanPeriod,
    locale: Locale = .current
) -> String? {
    let months: Int
    switch period {
    case .monthly:
        return nil
    case .sixMonth:
        months = 6
    case .annual:
        months = 12
    }

    // Kotlin's `Currency.getInstance(currencyCode)` throws for a code the platform does not
    // know, and `runCatching { ... }.getOrNull()` turns that into `null`. The Swift twin is
    // to reject a code that is not a known ISO 4217 currency before formatting.
    guard Locale.isoCurrencyCodes.contains(currencyCode) else {
        return nil
    }

    let perMonth = Double(amountMicros) / 1_000_000.0 / Double(months)

    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = locale
    formatter.currencyCode = currencyCode

    return formatter.string(from: NSNumber(value: perMonth))
}
