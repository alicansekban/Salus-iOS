// Ported 1:1 from Android
// `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/ui/
// AiSummaryUiState.kt`.

import SalusAI

/// Everything the summary screen can be showing below the period selector.
///
/// One member per outcome `AiSummaryRepository` can answer, because each one is a different
/// screen with a different call to action — a single "error" state would collapse "keep
/// logging", "subscribe" and "try again tomorrow" into one dead end.
public enum AiSummaryResult: Equatable, Sendable {
    case loading

    /// `fromCache` is true when the text was read back out of the cache, nothing spent.
    case content(text: String, fromCache: Bool)

    /// Too few recorded days in the period. The minimum lives in `:core:ai` and is not copied here.
    case insufficientData

    /// Not entitled and the one-off free summary is spent — the only state that offers the paywall.
    case premiumRequired

    /// Entitled, but today's quota is used up. Resets at the next local midnight.
    case dailyLimit

    /// The request failed, with the only distinction the user can act on.
    ///
    /// It carries a `SummaryFailureReason` and never a message: the repository's underlying text
    /// is raw SDK output kept for the log, so all copy on this screen is ours and localized.
    /// `.error` offers a retry and points at the connection; `.unavailable` does neither, because
    /// nothing the user does to their network will make an unconfigured build work.
    case error(reason: SummaryFailureReason)
}

/// The selected period is held next to `result` rather than inside it, so the segmented control
/// keeps its selection while the next summary loads.
public struct AiSummaryUiState: Equatable, Sendable {
    public var period: SummaryPeriod
    public var result: AiSummaryResult

    public init(
        period: SummaryPeriod = .weekly,
        result: AiSummaryResult = .loading
    ) {
        self.period = period
        self.result = result
    }
}

/// User intents on the summary screen.
public enum AiSummaryEvent: Equatable, Sendable {
    case periodSelected(SummaryPeriod)
    case retryClicked
    case upgradeClicked
}
