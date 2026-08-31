import Testing

@testable import SalusPremium

// Ported 1:1 from `PremiumStatusTest.kt` (4 cases). Case names are the Kotlin
// backtick names in camelCase.

@Suite("PremiumStatus (Android parity)")
struct PremiumStatusTests {
    @Test("an active entitlement with a billing issue is a grace period")
    func anActiveEntitlementWithABillingIssueIsAGracePeriod() {
        #expect(premiumStatusOf(entitlementActive: true, hasBillingIssue: true) == .gracePeriod)
    }

    @Test("an active entitlement without a billing issue is premium")
    func anActiveEntitlementWithoutABillingIssueIsPremium() {
        #expect(premiumStatusOf(entitlementActive: true, hasBillingIssue: false) == .premium)
    }

    @Test("an inactive entitlement is free whatever the billing issue flag says")
    func anInactiveEntitlementIsFreeWhateverTheBillingIssueFlagSays() {
        #expect(premiumStatusOf(entitlementActive: false, hasBillingIssue: false) == .free)
        #expect(premiumStatusOf(entitlementActive: false, hasBillingIssue: true) == .free)
    }

    @Test("premium and grace period are entitled, free is not")
    func premiumAndGracePeriodAreEntitledFreeIsNot() {
        #expect(PremiumStatus.premium.isEntitled == true)
        #expect(PremiumStatus.gracePeriod.isEntitled == true)
        #expect(PremiumStatus.free.isEntitled == false)
    }
}
