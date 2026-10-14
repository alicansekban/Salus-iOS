// Result types of `SmokingInsightsCalculator` (`smoking-domain-contract.md` section 5 in
// `salus-android`; Android twin: `SmokingInsights.kt`). Like the snapshot types they hold integers
// only: shares are permille 0-1000 and no floating-point value exists outside UI. Nothing here
// formats a currency, so the PDF and the AI prompt can show counts and shares with no symbol.

/// One trigger's `count` of events and its `permille` share of all events that carry a trigger.
public struct TriggerShare: Sendable, Equatable {
    public let trigger: CravingTrigger
    public let count: Int
    public let permille: Int

    public init(trigger: CravingTrigger, count: Int, permille: Int) {
        self.trigger = trigger
        self.count = count
        self.permille = permille
    }
}

// swiftlint:disable identifier_name
/// Heatmap rows, in declaration order. A band is the local hour of an event: `h08_10` is
/// 08:00-09:59 and `h22_08` is 22:00-07:59. The raw value is the Android enum name.
///
/// The case names keep the contract's `H08_10` shape (lowerCamel first letter only), so the two
/// platforms read the same in a vector or a review; the underscore is what `identifier_name`
/// objects to, hence the scoped disable.
public enum HourBand: String, Sendable, CaseIterable {
    case h08_10 = "H08_10"
    case h10_12 = "H10_12"
    case h12_14 = "H12_14"
    case h14_16 = "H14_16"
    case h16_18 = "H16_18"
    case h18_22 = "H18_22"
    case h22_08 = "H22_08"
}
// swiftlint:enable identifier_name

/// One attempt's length: `durationMs` is `end - start`, or `now - start` for the active one.
public struct AttemptDuration: Sendable, Equatable {
    public let attemptId: String
    public let durationMs: Int64

    public init(attemptId: String, durationMs: Int64) {
        self.attemptId = attemptId
        self.durationMs = durationMs
    }
}

/// The premium Trends figures.
///
/// `heatmap` has one row per `HourBand` (declaration order) and seven columns, ISO weekday 1-7
/// (Monday first), each cell an event count. `reductionWeekly` has one entry per 7-day bucket from
/// the setup day; nil is a bucket with no logged day ("no data", never 0, like `DayUnits`).
public struct SmokingInsights: Sendable, Equatable {
    public let hasEnoughData: Bool
    public let triggers: [TriggerShare]
    public let heatmap: [[Int]]
    public let busiestBand: HourBand?
    public let busiestBandPermille: Int
    public let reductionWeekly: [Int64?]
    public let attemptDurations: [AttemptDuration]
    public let quitMarkerEpochDays: [Int64]

    public init(
        hasEnoughData: Bool,
        triggers: [TriggerShare],
        heatmap: [[Int]],
        busiestBand: HourBand?,
        busiestBandPermille: Int,
        reductionWeekly: [Int64?],
        attemptDurations: [AttemptDuration],
        quitMarkerEpochDays: [Int64]
    ) {
        self.hasEnoughData = hasEnoughData
        self.triggers = triggers
        self.heatmap = heatmap
        self.busiestBand = busiestBand
        self.busiestBandPermille = busiestBandPermille
        self.reductionWeekly = reductionWeekly
        self.attemptDurations = attemptDurations
        self.quitMarkerEpochDays = quitMarkerEpochDays
    }
}

/// The only smoking data the AI summary may see (contract section 5): aggregate counts and shares,
/// never the plan's reason, never an instant, never money. A new field needs a contract change, and
/// `SmokingAiStatsTests.fieldSetPinned` pins the field set.
public struct SmokingAiStats: Sendable, Equatable {
    public let mode: SmokingMode
    public let daysTracked: Int
    public let slipCount: Int
    public let topTriggers: [TriggerShare]
    public let busiestBand: HourBand?
    /// REDUCE only. Not clamped: negative when the person smoked above baseline.
    public let reductionPercent: Int?

    public init(
        mode: SmokingMode,
        daysTracked: Int,
        slipCount: Int,
        topTriggers: [TriggerShare],
        busiestBand: HourBand?,
        reductionPercent: Int?
    ) {
        self.mode = mode
        self.daysTracked = daysTracked
        self.slipCount = slipCount
        self.topTriggers = topTriggers
        self.busiestBand = busiestBand
        self.reductionPercent = reductionPercent
    }
}
