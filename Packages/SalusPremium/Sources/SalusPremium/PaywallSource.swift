/// Where the user was when the paywall was asked for. Drives the paywall's headline copy.
/// Ported 1:1 from `PaywallController.kt:8-19`.
public enum PaywallSource: Sendable, Equatable, CaseIterable {
    case onboarding
    case settings
    case themes
    case trends
    case aiSummary
    case doctorReport
    case backup
}

/// An open paywall, and the reason it opened.
public struct PaywallRequest: Sendable, Equatable {
    public let source: PaywallSource

    public init(source: PaywallSource) {
        self.source = source
    }
}
