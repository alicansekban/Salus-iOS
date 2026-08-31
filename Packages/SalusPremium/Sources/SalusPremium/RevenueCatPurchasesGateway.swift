import Foundation
import RevenueCat

/// The only file in the app that talks to RevenueCat.
///
/// Everything the SDK reports is mapped onto this module's own types (``CustomerSnapshot``,
/// ``PaywallOffering``, ``PurchaseOutcome``) so no store type ever reaches a ViewModel or a screen.
///
/// **Never crashes without an API key.** `Purchases.configure` only runs when a key was built in
/// (see the app shell), so on a key-less build every call here short-circuits to a safe result: a
/// permanently FREE customer, no offering, and a purchase that reports an error instead of
/// throwing. Every SDK call is wrapped the same way, so a store outage degrades exactly like a
/// missing key. Ported 1:1 from `RevenueCatPurchasesGateway.kt`.
///
/// Not directly unit-tested (divergence (g)): the SDK is not exercised by `swift test`, so this
/// adapter is covered by the fake-backed repository tests plus manual QA, exactly as Android
/// covers it.
public final class RevenueCatPurchasesGateway: PurchasesGateway {
    public var isConfigured: Bool {
        Purchases.isConfigured
    }

    /// Entitlement pushes from the store, seeded with the current customer (when the store
    /// answers) so a collector never has to wait for a renewal to learn the status.
    ///
    /// The twin of the Android `callbackFlow` wrapping `updatedCustomerInfoListener`
    /// (`RevenueCatPurchasesGateway.kt:49-66`): iOS surfaces the same single-collector push stream
    /// as `Purchases.shared.customerInfoStream`, seeded here with a `currentCustomer()` answer.
    public var customerUpdates: AsyncStream<CustomerSnapshot> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let updates = Purchases.isConfigured ? Purchases.shared.customerInfoStream : AsyncStream { $0.finish() }
            let seedTask = Task {
                // Only a real answer is worth seeding with; a failed fetch leaves the collector on
                // its own default until the store actually reports something.
                if let snapshot = await currentCustomer() {
                    continuation.yield(snapshot)
                }
                for await info in updates {
                    continuation.yield(info.toSnapshot())
                }
            }
            continuation.onTermination = { _ in
                seedTask.cancel()
            }
        }
    }

    public init() {}

    public func currentCustomer() async -> CustomerSnapshot? {
        // Unconfigured is a definitive "no entitlement"; a thrown SDK error is not an answer at
        // all, so it maps to nil and the caller keeps whatever it already knew.
        guard isConfigured else { return Self.freeSnapshot }
        do {
            return try await Purchases.shared.customerInfo().toSnapshot()
        } catch {
            return nil
        }
    }

    public func currentOffering() async -> PaywallOffering? {
        do {
            let plans = try await Purchases.shared.offerings()
                .current?
                .availablePackages
                .compactMap { $0.toPlan() } ?? []
            return plans.isEmpty ? nil : PaywallOffering(plans: plans)
        } catch {
            return nil
        }
    }

    public func purchase(host: PurchaseHost, packageId: String) async -> PurchaseOutcome {
        guard isConfigured else { return .error(Self.notConfigured) }

        do {
            let packages = try await Purchases.shared.offerings()
                .current?
                .availablePackages ?? []
            guard let purchasePackage = packages.first(where: { $0.identifier == packageId }) else {
                return .error(Self.planUnavailable)
            }

            let result: PurchaseResultData = try await Purchases.shared.purchase(package: purchasePackage)
            if result.userCancelled {
                // Backing out of the store sheet is not a failure the paywall reports.
                return .cancelled
            }
            return .success
        } catch {
            return .error(Self.purchaseFailed)
        }
    }

    /// Unlike ``currentCustomer()``, a failed restore does report a free snapshot: the user asked
    /// an explicit question and the UI acts on the answer it gets, rather than silently keeping a
    /// status the store never confirmed.
    public func restore() async -> CustomerSnapshot {
        guard isConfigured else { return Self.freeSnapshot }
        do {
            return try await Purchases.shared.restorePurchases().toSnapshot()
        } catch {
            return Self.freeSnapshot
        }
    }
}

extension RevenueCatPurchasesGateway {
    fileprivate static let freeSnapshot = CustomerSnapshot(entitlementActive: false, hasBillingIssue: false)
    fileprivate static let notConfigured = "Purchases are not available in this build."
    fileprivate static let planUnavailable = "Plan is no longer available."
    fileprivate static let purchaseFailed = "The purchase could not be completed."
}

extension RevenueCatPurchasesGateway {
    fileprivate static let entitlementID = "premium"
}

extension CustomerInfo {
    fileprivate func toSnapshot() -> CustomerSnapshot {
        let premium = entitlements[RevenueCatPurchasesGateway.entitlementID]
        return CustomerSnapshot(
            entitlementActive: premium?.isActive == true,
            // Set while the store retries a failed renewal — the grace period.
            hasBillingIssue: premium?.billingIssueDetectedAt != nil
        )
    }
}

extension Package {
    /// Packages the paywall cannot show (weekly, lifetime, custom…) are dropped.
    fileprivate func toPlan() -> PremiumPlan? {
        let planPeriod: PlanPeriod
        switch packageType {
        case .monthly: planPeriod = .monthly
        case .sixMonth: planPeriod = .sixMonth
        case .annual: planPeriod = .annual
        default: return nil
        }

        let price = storeProduct.price
        let amountMicros = ((price as NSDecimalNumber).doubleValue * 1_000_000).rounded()

        return PremiumPlan(
            packageId: identifier,
            period: planPeriod,
            priceFormatted: storeProduct.localizedPriceString,
            monthlyEquivalent: monthlyEquivalentOf(
                amountMicros: Int64(amountMicros),
                currencyCode: storeProduct.currencyCode ?? "",
                period: planPeriod
            ),
            hasFreeTrial: storeProduct.introductoryDiscount?.paymentMode == .freeTrial
        )
    }
}
