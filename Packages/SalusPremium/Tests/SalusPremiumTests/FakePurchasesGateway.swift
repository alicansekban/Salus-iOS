import Foundation
import SalusPremium

// The test fake for `PurchasesGateway` — ported 1:1 from `FakePurchasesGateway` in
// `PremiumRepositoryImplTest.kt:94-125`.
//
// `@unchecked Sendable` over a lock rather than an actor because the protocol is not
// `@MainActor`-isolated; the same shape `FakeSettingsPreferences.swift` uses. Swift 6 disallows
// `NSLock.lock()` from an async context, so each async method delegates to a synchronous helper.
//
// The push-capable side (Android's `MutableSharedFlow` in the Kotlin fake) is a single pre-created
// stream whose continuation exists from construction — so a `publish(_:)` made before the
// repository's collection task subscribes is buffered (`bufferingNewest(1)`, the StateFlow
// conflation) rather than dropped, exactly the `runCurrent()`-after-init guarantee the Android
// `backgroundScope` test gives. The same shape `FakeSettingsPreferences.swift` uses for `themeMode`.

final class FakePurchasesGateway: PurchasesGateway, @unchecked Sendable {
    private let lock = NSLock()

    /// What the store reports on `currentCustomer()`; `nil` stands for a store that did not
    /// answer at all.
    private var customerValue: CustomerSnapshot?
    private var currentCustomerCallsValue = 0

    private let stream: AsyncStream<CustomerSnapshot>
    private let continuation: AsyncStream<CustomerSnapshot>.Continuation

    let isConfigured = true

    init(
        customer: CustomerSnapshot? = CustomerSnapshot(entitlementActive: false, hasBillingIssue: false)
    ) {
        customerValue = customer
        let made = AsyncStream.makeStream(of: CustomerSnapshot.self, bufferingPolicy: .bufferingNewest(1))
        stream = made.stream
        continuation = made.continuation
    }

    var customerUpdates: AsyncStream<CustomerSnapshot> {
        stream
    }

    /// The twin of Android's `MutableSharedFlow.emit` — pushes a snapshot to every collector.
    func publish(_ snapshot: CustomerSnapshot) {
        continuation.yield(snapshot)
    }

    func currentCustomer() async -> CustomerSnapshot? {
        currentCustomerCallsValue += 1
        return customerValue
    }

    func currentOffering() async -> PaywallOffering? {
        nil
    }

    func purchase(host: PurchaseHost, packageId: String) async -> PurchaseOutcome {
        .cancelled
    }

    func restore() async -> CustomerSnapshot {
        customerValue ?? freeSnapshot
    }

    /// The store's answer to `currentCustomer()`; assign `nil` for a store that did not answer.
    var customer: CustomerSnapshot? {
        get { customerValue }
        set { customerValue = newValue }
    }

    var currentCustomerCalls: Int {
        currentCustomerCallsValue
    }
}

/// The free snapshot Android's `FakePurchasesGateway` hardcodes; mirrored here for restore's fallback.
private let freeSnapshot = CustomerSnapshot(entitlementActive: false, hasBillingIssue: false)
