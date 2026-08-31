import Foundation

/// How a purchase attempt ended.
///
/// A user backing out of the store sheet is ``cancelled``, not an ``error`` — the paywall stays
/// open and says nothing. Ported 1:1 from `PurchasesGateway.kt:11-15`.
public enum PurchaseOutcome: Sendable, Equatable {
    case success
    case cancelled
    case error(String)
}

/// The surface a purchase sheet needs to attach to.
///
/// An opaque marker here on purpose: this module knows nothing about view controllers or
/// windows, and the UI layer passes whatever the store SDK requires. The iOS implementation
/// is ``WindowPurchaseHost`` (divergence (c)) — see `WindowPurchaseHost.swift`.
public protocol PurchaseHost: Sendable {}

/// The one seam between this module and the billing SDK.
///
/// Everything else in `:core:premium` is pure code and testable with a fake gateway; only the
/// adapter implementing this interface touches the SDK. Ported 1:1 from `PurchasesGateway.kt:31-55`.
public protocol PurchasesGateway: Sendable {
    /// False when no store API key was supplied, e.g. in debug builds — nothing may be sold.
    var isConfigured: Bool { get }

    /// Entitlement changes the store pushes, including renewals and expiries.
    var customerUpdates: AsyncStream<CustomerSnapshot> { get }

    /// The customer as the store sees it right now, or `nil` when the store did not answer.
    ///
    /// `nil` is not "free": a network blip must never downgrade someone who paid, so callers keep
    /// the last known entitlement instead. An unconfigured SDK is a definitive answer, not a
    /// failure — it returns a free snapshot.
    func currentCustomer() async -> CustomerSnapshot?

    /// The plans to show, or `nil` when the SDK is not configured or offers nothing.
    func currentOffering() async -> PaywallOffering?

    func purchase(host: PurchaseHost, packageId: String) async -> PurchaseOutcome

    /// Re-reads purchases the user already owns, e.g. on a new device.
    func restore() async -> CustomerSnapshot
}
