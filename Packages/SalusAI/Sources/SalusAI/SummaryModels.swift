// Ported 1:1 from Android
// `core/ai/src/main/kotlin/com/alicansekban/salus/core/ai/SummaryModels.kt`.

import SalusModel

/// Aggregation window a `HealthPeriodStats` snapshot covers.
public enum SummaryPeriod: Sendable {
    case weekly
    case monthly
}

/// Output language requested from the model. Prompt copy is fixed per language.
public enum AiLanguage: Sendable {
    case tr
    case en
}

/// The fixed sentence every AI-generated artefact ends with.
///
/// Deliberately one function rather than a string per call site: the summary text carries it
/// appended before the row is cached, and the exported PDF renders it on the footer of every
/// page. The wording is a medical-disclaimer commitment, so the two must never drift apart by a
/// word — which is also why this is public rather than a resource string. A `values-*` entry
/// follows the device configuration, while this follows the `AiLanguage` the artefact was
/// generated in, and those are the same thing only until someone switches language mid-report.
public func disclaimerFor(_ language: AiLanguage) -> String {
    switch language {
    case .tr: "Bu rapor bilgilendirme amaçlıdır, tıbbi tavsiye değildir."
    case .en: "This report is for informational purposes only and is not medical advice."
    }
}

/// AI calls one device may make in a day, across every AI feature. Applies to entitled users
/// too — it is a cost ceiling, not an entitlement.
///
/// Public and shared rather than per-repository: the summary and the doctor report draw on the
/// same counter, so two limits would let a user make ten calls by alternating between them.
public let dailyAiCallLimit = 5

/// Recorded days a period needs before a model call is worth making. A week of two readings
/// produces confident-sounding prose about noise, which is the worst thing this feature can do.
///
/// The doctor report reads the same threshold: below it the deterministic tables are still
/// printed, but the AI narrative is left out rather than written about nothing.
extension SummaryPeriod {
    public var minimumRecordDays: Int {
        switch self {
        case .weekly: weeklyMinRecordDays
        case .monthly: monthlyMinRecordDays
        }
    }
}

private let weeklyMinRecordDays = 3
private let monthlyMinRecordDays = 7

/// Aggregated, de-identified health statistics for one period.
///
/// Intentionally contains no name, birth date, note text or any other free-form user input:
/// this is the only payload that ever reaches the model.
///
/// - `distinctRecordDays`: number of days within the period that have at least one record.
/// - `loggedDoses`: intake rows the user actually recorded in the period, whatever their
///   status. This is NOT the number of doses the schedule called for: nothing writes a row for a
///   dose the user never interacted with, so a dose that was silently missed is absent from this
///   count entirely.
/// - `takenDoses`: subset of `loggedDoses` marked as taken.
public struct HealthPeriodStats: Equatable, Sendable {
    public let periodType: SummaryPeriod
    public let startEpochDay: Int
    public let endEpochDay: Int
    public let distinctRecordDays: Int
    public let systolic: MetricStats?
    public let diastolic: MetricStats?
    public let pulse: MetricStats?
    public let glucoseMgDl: MetricStats?
    public let weightKg: MetricStats?
    public let loggedDoses: Int
    public let takenDoses: Int

    public init(
        periodType: SummaryPeriod,
        startEpochDay: Int,
        endEpochDay: Int,
        distinctRecordDays: Int,
        systolic: MetricStats?,
        diastolic: MetricStats?,
        pulse: MetricStats?,
        glucoseMgDl: MetricStats?,
        weightKg: MetricStats?,
        loggedDoses: Int,
        takenDoses: Int
    ) {
        self.periodType = periodType
        self.startEpochDay = startEpochDay
        self.endEpochDay = endEpochDay
        self.distinctRecordDays = distinctRecordDays
        self.systolic = systolic
        self.diastolic = diastolic
        self.pulse = pulse
        self.glucoseMgDl = glucoseMgDl
        self.weightKg = weightKg
        self.loggedDoses = loggedDoses
        self.takenDoses = takenDoses
    }

    /// Share of *recorded* doses marked as taken, as a whole percentage, or `nil` when nothing
    /// was recorded (in which case the ratio is undefined rather than zero).
    ///
    /// This is deliberately not called adherence: the denominator is `loggedDoses`, so a user who
    /// records only the doses they take reads as 100% here while having missed doses that were
    /// never written down. Copy built on this value must say what it measures.
    ///
    /// Rounded to the nearest whole percent rather than truncated. Integer division would report
    /// two doses out of three as 66 and under-state every ratio that does not divide evenly, and
    /// the trends screen computes the same share the same way — one number, one rule, whichever
    /// surface the user reads it on.
    public var takenPercent: Int? {
        if loggedDoses <= 0 {
            return nil
        }
        return Int((Double(takenDoses) * 100 / Double(loggedDoses)).rounded())
    }
}

/// A model request split into its fixed system instruction and the generated user message.
public struct AiPrompt: Equatable, Sendable {
    public let system: String
    public let user: String

    public init(system: String, user: String) {
        self.system = system
        self.user = user
    }
}
