// Ported 1:1 from Android
// `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/ui/
// AiSummaryUiState.kt`.

import SalusAI
import SalusModel

/// Everything the summary screen can be showing below the period selector.
///
/// One member per outcome `AiSummaryRepository` can answer, because each one is a different
/// screen with a different call to action — a single "error" state would collapse "keep
/// logging", "subscribe" and "try again tomorrow" into one dead end.
public enum AiSummaryResult: Equatable, Sendable {
    case loading

    /// `fromCache` is true when the text was read back out of the cache, nothing spent.
    /// `metrics` are the period's headline figures, or nil when it holds none of them
    /// (`AiSummaryUiState.kt:25-29`).
    case content(text: String, fromCache: Bool, metrics: AiSummaryMetrics? = nil)

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

/// The three figures the summary screen puts above the text, taken from the same de-identified
/// snapshot the model was given (`AiSummaryUiState.kt:52-89`).
///
/// Every field is nil and the whole type is nil at its use site, because a period is allowed to
/// hold one of these and not the others: a user who logs weight only has no blood pressure to
/// average, and a tile reading "0" would be a claim about their health rather than an absence of
/// data. The screen drops each nil tile, and the row with it when all three are gone.
///
/// - `averageBloodPressure`: pre-formatted "128/82", or just the systolic average when no reading
///   in the period carried a diastolic value. Digits and a slash only, so there is nothing here
///   for a locale to disagree about.
/// - `recordedDosePercent`: share of the doses the user *recorded* that are marked taken.
///   Deliberately not a claim about scheduled doses — see `HealthPeriodStats.takenPercent` — and
///   the label above it says so (`AiSummaryUiState.kt:64-67`).
public struct AiSummaryMetrics: Equatable, Sendable {
    public let averageBloodPressure: String?
    public let recordedDosePercent: Int?
    public let averagePulse: Int?

    public init(
        averageBloodPressure: String? = nil,
        recordedDosePercent: Int? = nil,
        averagePulse: Int? = nil
    ) {
        self.averageBloodPressure = averageBloodPressure
        self.recordedDosePercent = recordedDosePercent
        self.averagePulse = averagePulse
    }

    /// The snapshot's three headline figures, or `nil` when it carries none of them
    /// (`AiSummaryUiState.kt:76-87`).
    public static func of(_ stats: HealthPeriodStats) -> AiSummaryMetrics? {
        let metrics = AiSummaryMetrics(
            averageBloodPressure: stats.averageBloodPressureOrNil(),
            recordedDosePercent: stats.takenPercent,
            averagePulse: stats.pulse?.average.intValue()
        )
        let empty = metrics.averageBloodPressure == nil
            && metrics.recordedDosePercent == nil
            && metrics.averagePulse == nil
        return empty ? nil : metrics
    }
}

extension HealthPeriodStats {
    /// "128/82" from the period's averages, or `nil` when nothing measured a systolic value
    /// (`AiSummaryUiState.kt:97-101`).
    ///
    /// The diastolic half is appended only when it exists: a reading may be stored without one,
    /// and printing "128/0" would invent a number the user never recorded.
    fileprivate func averageBloodPressureOrNil() -> String? {
        guard let systolicAverage = systolic?.average.rounded().intValue() else { return nil }
        guard let diastolicAverage = diastolic?.average.rounded().intValue() else {
            return "\(systolicAverage)"
        }
        return "\(systolicAverage)/\(diastolicAverage)"
    }
}

extension Double {
    /// Kotlin's `roundToInt()` — the values a metric tile shows are whole numbers.
    fileprivate func intValue() -> Int {
        Int(rounded())
    }
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
