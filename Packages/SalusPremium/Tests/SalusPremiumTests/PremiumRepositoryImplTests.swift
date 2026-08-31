import SalusPremium
import Testing

@Suite("PremiumRepositoryImpl (Android parity)")
@MainActor
struct PremiumRepositoryImplTests {
    @Test("the status starts free before the gateway reports anything")
    func theStatusStartsFreeBeforeTheGatewayReportsAnything() {
        let gateway = FakePurchasesGateway()
        let repository = PremiumRepositoryImpl(gateway: gateway)

        #expect(repository.currentStatus == .free)
    }

    @Test("the status follows every customer update the gateway publishes")
    func theStatusFollowsEveryCustomerUpdateTheGatewayPublishes() async {
        let gateway = FakePurchasesGateway()
        let repository = PremiumRepositoryImpl(gateway: gateway)
        #expect(repository.currentStatus == .free)

        gateway.publish(CustomerSnapshot(entitlementActive: true, hasBillingIssue: false))
        await waitUntil("premium") { repository.currentStatus == .premium }

        gateway.publish(CustomerSnapshot(entitlementActive: true, hasBillingIssue: true))
        await waitUntil("grace period") { repository.currentStatus == .gracePeriod }

        gateway.publish(CustomerSnapshot(entitlementActive: false, hasBillingIssue: false))
        await waitUntil("free") { repository.currentStatus == .free }
    }

    @Test("refresh pulls the current customer from the gateway")
    func refreshPullsTheCurrentCustomerFromTheGateway() async {
        let gateway = FakePurchasesGateway(
            customer: CustomerSnapshot(entitlementActive: true, hasBillingIssue: true)
        )
        let repository = PremiumRepositoryImpl(gateway: gateway)
        #expect(repository.currentStatus == .free)

        await repository.refresh()

        #expect(repository.currentStatus == .gracePeriod)
        #expect(gateway.currentCustomerCalls == 1)
    }

    @Test("refresh keeps the last known status when the store does not answer")
    func refreshKeepsTheLastKnownStatusWhenTheStoreDoesNotAnswer() async {
        let gateway = FakePurchasesGateway()
        let repository = PremiumRepositoryImpl(gateway: gateway)
        gateway.publish(CustomerSnapshot(entitlementActive: true, hasBillingIssue: false))
        await waitUntil("premium") { repository.currentStatus == .premium }

        // The store is unreachable: it answers with nothing, not with "this user is free".
        gateway.customer = nil
        await repository.refresh()

        #expect(repository.currentStatus == .premium)
    }

    @Test("a failed refresh never downgrades a user who is in the grace period")
    func aFailedRefreshNeverDowngradesAUserWhoIsInTheGracePeriod() async {
        let gateway = FakePurchasesGateway()
        let repository = PremiumRepositoryImpl(gateway: gateway)
        gateway.publish(CustomerSnapshot(entitlementActive: true, hasBillingIssue: true))
        await waitUntil("grace period") { repository.currentStatus == .gracePeriod }

        gateway.customer = nil
        await repository.refresh()
        await repository.refresh()

        #expect(repository.currentStatus == .gracePeriod)
        #expect(gateway.currentCustomerCalls == 2)
    }

    /// The twin of Android's `runCurrent()` / `advanceUntilIdle()`: the repository's collection
    /// `Task` applies pushed snapshots off-thread, so a test must hand the cooperative pool a few
    /// yields before asserting the derived `currentStatus`.
    private func waitUntil(
        _ what: String,
        limit: Int = 1000,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ condition: () -> Bool
    ) async {
        for _ in 0 ..< limit {
            if condition() {
                return
            }
            await Task.yield()
        }
        Issue.record("timed out waiting for \(what)", sourceLocation: sourceLocation)
    }
}
