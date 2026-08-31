// The test fakes for `PaywallViewModelTests` — ported 1:1 from the fakes in
// `PaywallViewModelTest.kt:29-97` (FakePurchaseHost, the three plans, FakePurchasesGateway).
//
// `@unchecked Sendable` over a lock rather than an actor because the protocols are not
// `@MainActor`-isolated; the same shape `FakePurchasesGateway` in `SalusPremiumTests` uses.
// Swift 6 disallows `NSLock.lock()` from an async context, so the async methods mutate their
// counters directly — the ViewModel is `@MainActor` and calls them from the main actor — while
// the lock guards the synchronous property accessors a test may read from any thread.

import Foundation
import SalusPremium

/// A no-op `PurchaseHost`, the twin of Android's `private object FakePurchaseHost`.
struct FakePurchaseHost: PurchaseHost {}

/// The three plans the Android fake hardcodes (`PaywallViewModelTest.kt:31-51`).
let monthly = PremiumPlan(
    packageId: "monthly",
    period: .monthly,
    priceFormatted: "₺49,99",
    monthlyEquivalent: nil,
    hasFreeTrial: false
)
let sixMonth = PremiumPlan(
    packageId: "six_month",
    period: .sixMonth,
    priceFormatted: "₺249,99",
    monthlyEquivalent: "₺41,66",
    hasFreeTrial: false
)
let annual = PremiumPlan(
    packageId: "annual",
    period: .annual,
    priceFormatted: "₺399,99",
    monthlyEquivalent: "₺33,33",
    hasFreeTrial: true
)

/// A one-shot suspension gate — the twin of Kotlin's `CompletableDeferred<Unit>`.
///
/// `awaitIfSet()` suspends until `open()` resumes it. The fake only awaits when a gate is
/// installed, so a test can hold a purchase or restore mid-flight and then release it.
final class Gate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var opened = false

    func awaitIfSet() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            lock.lock()
            if opened {
                lock.unlock()
                cont.resume()
            } else {
                continuation = cont
                lock.unlock()
            }
        }
    }

    func open() {
        lock.lock()
        opened = true
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume()
    }
}

/// The test fake for `PurchasesGateway` — ported 1:1 from `FakePurchasesGateway` in
/// `PaywallViewModelTest.kt:53-97`.
final class FakePurchasesGateway: PurchasesGateway, @unchecked Sendable {
    private let lock = NSLock()

    /// What the store reports on `currentOffering()`; `nil` stands for a store that offers nothing.
    private var offeringValue: PaywallOffering?
    /// What the store reports on `currentCustomer()`; `nil` stands for a store that did not answer.
    private var customerValue: CustomerSnapshot?
    private var restoreSnapshotValue: CustomerSnapshot
    private var purchaseOutcomeValue: PurchaseOutcome

    /// Set to suspend `purchase` until opened, so a second click can arrive mid-flight.
    private var purchaseGateValue: Gate?
    /// Same, for `restore`: a restore in flight must block the buttons behind it.
    private var restoreGateValue: Gate?

    private var purchaseCallsValue = 0
    private var restoreCallsValue = 0
    private var offeringCallsValue = 0
    private var currentCustomerCallsValue = 0
    private var purchasedPackageIdsValue: [String] = []

    private let stream: AsyncStream<CustomerSnapshot>
    private let continuation: AsyncStream<CustomerSnapshot>.Continuation

    let isConfigured = true

    init(
        offering: PaywallOffering? = PaywallOffering(plans: [monthly, sixMonth, annual]),
        customer: CustomerSnapshot? = CustomerSnapshot(entitlementActive: true, hasBillingIssue: false),
        restoreSnapshot: CustomerSnapshot = CustomerSnapshot(entitlementActive: false, hasBillingIssue: false),
        purchaseOutcome: PurchaseOutcome = .success
    ) {
        offeringValue = offering
        customerValue = customer
        restoreSnapshotValue = restoreSnapshot
        purchaseOutcomeValue = purchaseOutcome
        let made = AsyncStream.makeStream(of: CustomerSnapshot.self, bufferingPolicy: .bufferingNewest(1))
        stream = made.stream
        continuation = made.continuation
    }

    var customerUpdates: AsyncStream<CustomerSnapshot> { stream }

    var offering: PaywallOffering? {
        get { lock.lock()
            defer { lock.unlock() }
            return offeringValue
        }
        set { lock.lock()
            offeringValue = newValue
            lock.unlock()
        }
    }

    var customer: CustomerSnapshot? {
        get { lock.lock()
            defer { lock.unlock() }
            return customerValue
        }
        set { lock.lock()
            customerValue = newValue
            lock.unlock()
        }
    }

    var restoreSnapshot: CustomerSnapshot {
        get { lock.lock()
            defer { lock.unlock() }
            return restoreSnapshotValue
        }
        set { lock.lock()
            restoreSnapshotValue = newValue
            lock.unlock()
        }
    }

    var purchaseOutcome: PurchaseOutcome {
        get { lock.lock()
            defer { lock.unlock() }
            return purchaseOutcomeValue
        }
        set { lock.lock()
            purchaseOutcomeValue = newValue
            lock.unlock()
        }
    }

    var purchaseGate: Gate? {
        get { lock.lock()
            defer { lock.unlock() }
            return purchaseGateValue
        }
        set { lock.lock()
            purchaseGateValue = newValue
            lock.unlock()
        }
    }

    var restoreGate: Gate? {
        get { lock.lock()
            defer { lock.unlock() }
            return restoreGateValue
        }
        set { lock.lock()
            restoreGateValue = newValue
            lock.unlock()
        }
    }

    var purchaseCalls: Int {
        lock.lock()
        defer { lock.unlock() }
        return purchaseCallsValue
    }

    var restoreCalls: Int {
        lock.lock()
        defer { lock.unlock() }
        return restoreCallsValue
    }

    var offeringCalls: Int {
        lock.lock()
        defer { lock.unlock() }
        return offeringCallsValue
    }

    var currentCustomerCalls: Int {
        lock.lock()
        defer { lock.unlock() }
        return currentCustomerCallsValue
    }

    var purchasedPackageIds: [String] {
        lock.lock()
        defer { lock.unlock() }
        return purchasedPackageIdsValue
    }

    /// The async methods mutate their counters directly rather than under the lock, exactly as
    /// `FakePurchasesGateway` in `SalusPremiumTests` does: the ViewModel is `@MainActor` and calls
    /// them from the main actor, so there is no concurrent access to guard. The lock exists for the
    /// synchronous property accessors, which a test may read from any thread.
    func currentCustomer() async -> CustomerSnapshot? {
        currentCustomerCallsValue += 1
        return customerValue
    }

    func currentOffering() async -> PaywallOffering? {
        offeringCallsValue += 1
        return offeringValue
    }

    func purchase(host: PurchaseHost, packageId: String) async -> PurchaseOutcome {
        purchaseCallsValue += 1
        purchasedPackageIdsValue.append(packageId)
        await purchaseGateValue?.awaitIfSet()
        return purchaseOutcome
    }

    func restore() async -> CustomerSnapshot {
        restoreCallsValue += 1
        await restoreGateValue?.awaitIfSet()
        return restoreSnapshot
    }
}

/// The test fake for `PremiumRepository` — records `refreshCalls` and, on refresh, re-reads the
/// store through the gateway exactly as `PremiumRepositoryImpl` does, so a successful purchase or
/// restore flips the held status to `.premium` (the assertion `PaywallViewModelTest.kt:163` makes).
final class FakePremiumRepository: PremiumRepository, @unchecked Sendable {
    private let lock = NSLock()
    private let gateway: FakePurchasesGateway
    private var refreshCallsValue = 0
    private var statusValue: PremiumStatus

    private let stream: AsyncStream<PremiumStatus>
    private let continuation: AsyncStream<PremiumStatus>.Continuation

    init(gateway: FakePurchasesGateway, status: PremiumStatus = .free) {
        self.gateway = gateway
        statusValue = status
        let made = AsyncStream.makeStream(of: PremiumStatus.self, bufferingPolicy: .bufferingNewest(1))
        stream = made.stream
        continuation = made.continuation
    }

    var status: AsyncStream<PremiumStatus> { stream }

    var refreshCalls: Int {
        lock.lock()
        defer { lock.unlock() }
        return refreshCallsValue
    }

    var currentStatus: PremiumStatus {
        lock.lock()
        defer { lock.unlock() }
        return statusValue
    }

    func refresh() async {
        refreshCallsValue += 1
        // Mirror `PremiumRepositoryImpl.refresh()`: a nil answer leaves the status untouched.
        guard let snapshot = await gateway.currentCustomer() else { return }
        let status = premiumStatusOf(
            entitlementActive: snapshot.entitlementActive,
            hasBillingIssue: snapshot.hasBillingIssue
        )
        statusValue = status
        continuation.yield(status)
    }
}
