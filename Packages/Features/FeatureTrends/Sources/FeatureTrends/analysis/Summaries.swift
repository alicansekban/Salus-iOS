// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/analysis/Summaries.kt`.

import SalusModel

/// What one metric amounted to in the window, next to what it amounted to in the window before
/// (`Summaries.kt:33-38`).
///
/// `current` is never absent: a metric with no reading produces no summary at all, which is why
/// there is no such thing as a row of zeros here. `previous` is absent whenever the earlier
/// window holds no reading of this metric, and that absence is deliberately not collapsed into a
/// change of zero — "we have nothing to compare against" and "it held still" are different facts
/// and the card says different things about them.
///
/// `changePercent` is a plain relative move of the two averages, signed, and nothing more. It
/// carries no judgement and the copy built on it may not add one: a metric that rose 8% rose 8%,
/// whether that is welcome or unwelcome is a conversation with a doctor and not something this
/// screen is in a position to have.
///
/// Blood pressure is summarised on its systolic number, the way the overlay and the weekly card
/// reduce it, because one number per metric is what a row of this card can hold.
public struct MetricSummary: Equatable, Sendable {
    /// The metric this row is about.
    public let type: VitalType
    /// Count, average, lowest, highest and direction over the window asked for.
    public let current: MetricStats
    /// The same over the equally long window immediately before it, or `nil`.
    public let previous: MetricStats?
    /// `((current - previous) / previous) * 100`, or `nil` when there is no previous average, or
    /// when that average is `0.0` and the division has no answer.
    public let changePercent: Double?

    public init(
        type: VitalType,
        current: MetricStats,
        previous: MetricStats?,
        changePercent: Double?
    ) {
        self.type = type
        self.current = current
        self.previous = previous
        self.changePercent = changePercent
    }
}

/// Every metric the window holds a reading of, in `VitalType` order (`Summaries.kt:47`).
///
/// The order is fixed rather than taken from the records so that a metric keeps its place between
/// two loads of the same screen; ordering by, say, how much each moved would rearrange the card
/// every time a reading is logged.
public struct MetricSummaries: Equatable, Sendable {
    public let items: [MetricSummary]

    public init(items: [MetricSummary]) {
        self.items = items
    }
}

/// Summarises every metric in `current`, comparing each against `previous` (`Summaries.kt:60-67`).
///
/// Pure and total. Both lists are expected to be already windowed — they come from two reads of
/// two adjacent windows — so no day filtering happens here; what is passed in is what is
/// summarised.
///
/// A metric present in `previous` but not in `current` produces no row: this card is about the
/// window the user is looking at, and a metric they have stopped measuring has nothing to report
/// in it beyond its own absence.
public func metricSummariesOf(
    current: [TrendMeasurement],
    previous: [TrendMeasurement]
) -> MetricSummaries {
    MetricSummaries(
        items: VitalType.allCases.compactMap { type in
            metricSummaryOrNull(type: type, current: current, previous: previous)
        }
    )
}

/// The summaries the trends screen shows, or `nil` when the window holds no measurement
/// (`Summaries.kt:77-80`).
///
/// A window of nothing but dose records has nothing this card can say, and `nil` rather than an
/// empty `MetricSummaries` is what keeps the screen from drawing an empty one — the same shape
/// `metricOverlayOrNull`, `timeOfDayBreakdownOrNull` and `doseWeeksOrNull` use for the same
/// reason.
public func metricSummariesOrNull(
    current: [TrendMeasurement],
    previous: [TrendMeasurement]
) -> MetricSummaries? {
    let summaries = metricSummariesOf(current: current, previous: previous)
    return summaries.items.isEmpty ? nil : summaries
}

private func metricSummaryOrNull(
    type: VitalType,
    current: [TrendMeasurement],
    previous: [TrendMeasurement]
) -> MetricSummary? {
    guard let currentStats = metricStatsOf(current.orderedValuesOf(type)) else { return nil }
    let previousStats = metricStatsOf(previous.orderedValuesOf(type))
    return MetricSummary(
        type: type,
        current: currentStats,
        previous: previousStats,
        changePercent: changePercentOrNull(
            current: currentStats.average,
            previous: previousStats?.average
        )
    )
}

/// One metric's readings, oldest first (`Summaries.kt:109-112`).
///
/// The sort is not cosmetic. `metricStatsOf` reads its input as chronological and derives the
/// direction from the first half against the last half, so a list in whatever order the database
/// returned would produce a direction that depends on a sort nobody promised. Days alone are not
/// enough to order by either — a metric can be measured twice in one day, and morning and evening
/// readings of it are exactly the pair that differ.
extension [TrendMeasurement] {
    fileprivate func orderedValuesOf(_ type: VitalType) -> [Double] {
        filter { $0.type == type }
            .sorted { lhs, rhs in
                if lhs.epochDay != rhs.epochDay {
                    return lhs.epochDay < rhs.epochDay
                }
                return lhs.minuteOfDay < rhs.minuteOfDay
            }
            .map(\.primary)
    }
}

/// The relative move from `previous` to `current`, as a signed percentage, or `nil`
/// (`Summaries.kt:121-124`).
///
/// `nil` covers both ways the question can have no answer: there was no earlier average at all,
/// or that average was zero and the division has no result. Neither is reported as `0.0`, which
/// would be the claim that the metric held still.
private func changePercentOrNull(current: Double, previous: Double?) -> Double? {
    guard let previous, previous != 0.0 else { return nil }
    return (current - previous) / previous * percentMultiplier
}

/// A ratio becomes a percentage (`Summaries.kt:127`).
private let percentMultiplier = 100.0
