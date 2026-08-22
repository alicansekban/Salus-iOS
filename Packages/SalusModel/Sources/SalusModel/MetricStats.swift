// Ported 1:1 from Android
// `core/model/src/main/kotlin/com/alicansekban/salus/core/model/MetricStats.kt`.
//
// `metricStatsOf` and `trendOf` are free functions here as they are there — they belong to no
// type, and wrapping them in a namespace enum would be a gratuitous difference at every call site.

/// Direction of change of a metric across the period.
///
/// Raw values are the Kotlin constant names (`MetricStats.kt:6`).
public enum Trend: String, CaseIterable, Equatable, Hashable, Sendable {
    case rising = "RISING"
    case falling = "FALLING"
    case stable = "STABLE"
}

/// Numeric summary of a single health metric over a period.
///
/// Holds no raw measurements and no timestamps, so it can never carry identifying data.
/// The Kotlin data class is `MetricStats.kt:13-19`.
public struct MetricStats: Equatable, Sendable {
    public let count: Int
    public let average: Double
    public let min: Double
    public let max: Double
    public let trend: Trend

    public init(count: Int, average: Double, min: Double, max: Double, trend: Trend) {
        self.count = count
        self.average = average
        self.min = min
        self.max = max
        self.trend = trend
    }
}

/// Summarises one metric's series, or `nil` when nothing was measured — an absent metric is
/// omitted from the prompt entirely rather than reported as zero.
///
/// - Parameter values: the metric's readings; `trendOf` reads them as chronological.
public func metricStatsOf(_ values: [Double]) -> MetricStats? {
    // MetricStats.kt:27-36. `min()`/`max()` are optional in Swift, so the emptiness check that
    // Kotlin writes once is expressed by unwrapping them.
    guard let minimum = values.min(), let maximum = values.max() else { return nil }
    return MetricStats(
        count: values.count,
        average: averageOf(values),
        min: minimum,
        max: maximum,
        trend: trendOf(values)
    )
}

/// Compares the average of the first half of a chronological series against the last half. Only a
/// move larger than `trendBand` of the first half counts as direction; anything smaller is noise.
///
/// Series shorter than `minTrendSamples` are `.stable`: two or three readings cannot distinguish a
/// trend from day-to-day variation. On an odd-sized series the middle reading belongs to neither
/// half, which keeps the two halves the same size.
public func trendOf(_ orderedValues: [Double]) -> Trend {
    // MetricStats.kt:46-58.
    if orderedValues.count < minTrendSamples {
        return .stable
    }
    let halfSize = orderedValues.count / 2
    let earlier = averageOf(orderedValues.prefix(halfSize))
    let later = averageOf(orderedValues.suffix(halfSize))
    let band = abs(earlier) * trendBand
    let change = later - earlier
    if change > band {
        return .rising
    }
    if change < -band {
        return .falling
    }
    return .stable
}

/// Kotlin's `Iterable<Double>.average()`, which the two functions above lean on. Only ever called
/// with a non-empty collection.
private func averageOf(_ values: some Collection<Double>) -> Double {
    values.reduce(0, +) / Double(values.count)
}

/// Fewer readings than this cannot separate a trend from day-to-day variation
/// (`MetricStats.kt:61`, `MIN_TREND_SAMPLES`).
private let minTrendSamples = 4

/// Relative move below which a metric is reported as `.stable`
/// (`MetricStats.kt:64`, `TREND_BAND`).
private let trendBand = 0.05
