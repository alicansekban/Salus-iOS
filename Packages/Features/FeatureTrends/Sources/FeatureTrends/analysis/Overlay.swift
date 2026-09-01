// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/analysis/Overlay.kt`.

import SalusModel

/// One day of one metric, already placed on the shared axis (`Overlay.kt:20`).
///
/// Deliberately its own type rather than the `SalusUI` chart point: this package is reachable
/// from `domain/`, and an analysis that names a chart model is an analysis the iOS port cannot
/// reuse. The screen maps this to a chart point at the UI edge, which is the only place the two
/// worlds meet.
public struct OverlayPoint: Equatable, Hashable, Sendable {
    /// The local day the average belongs to — the day itself when the window is sampled daily,
    /// and the Monday the week starts on when it is sampled weekly.
    public let xEpochDay: Int
    /// Where the value falls between its own series' minimum and maximum, `0...1`.
    public let y: Float

    public init(xEpochDay: Int, y: Float) {
        self.xEpochDay = xEpochDay
        self.y = y
    }
}

/// One metric's line on the overlay (`Overlay.kt:39-44`).
///
/// `points` is normalized, because millimetres of mercury, milligrams per decilitre and
/// kilograms share no scale: drawn raw, weight would be a flat line along the bottom of a chart
/// whose axis belongs to blood pressure. Normalizing is what makes the *shapes* comparable, and
/// it is also why the real numbers have to travel alongside — `min` and `max` are what the card
/// writes out, since the axis itself can no longer show one.
///
/// `min` and `max` describe the points that are actually drawn, not the raw readings behind them:
/// on a weekly window they are the smallest and largest weekly average. A legend that quoted a
/// single extreme reading would name a number no point on the line ever reaches, and the card has
/// no axis left to reconcile the two.
public struct OverlaySeries: Equatable, Sendable {
    public let type: VitalType
    public let points: [OverlayPoint]
    /// The smallest plotted value in the window, in the metric's own unit.
    public let min: Double
    /// The largest plotted value in the window, in the metric's own unit.
    public let max: Double

    public init(type: VitalType, points: [OverlayPoint], min: Double, max: Double) {
        self.type = type
        self.points = points
        self.min = min
        self.max = max
    }
}

/// How finely the overlay samples its window: a point per day, or a point per week (`Overlay.kt:47`).
public enum OverlayBucket: Sendable, Equatable {
    case daily
    case weekly
}

/// Every metric the window has something to say about, on one shared axis (`Overlay.kt:56-59`).
///
/// `bucket` travels with the series because the card has to say which it is drawing. "Weekly
/// average" and "daily average" are different claims about the same line, and the legend's numbers
/// belong to whichever one was used.
public struct MetricOverlay: Equatable, Sendable {
    public let series: [OverlaySeries]
    public let bucket: OverlayBucket

    public init(series: [OverlaySeries], bucket: OverlayBucket = .daily) {
        self.series = series
        self.bucket = bucket
    }
}

/// Lays every metric in `measurements` over one another across `days` (`Overlay.kt:83-91`).
///
/// Pure and total, and three reductions happen here rather than in the UI:
///
/// 1. Days outside `days` are dropped first. The window is the question the user asked, and a
///    stray reading from before it would move a series' minimum and maximum — which is to say,
///    it would silently rescale a line the user is looking at.
/// 2. A day's readings collapse to that day's average, and on a window longer than
///    `maxDailyOverlayDays` the days then collapse to weekly averages. This chart compares
///    periods, so several points stacked on one x value would add vertical noise that answers a
///    different question — and so would three hundred and sixty-five of them side by side.
/// 3. Each series is scaled by its own minimum and maximum, not by a shared one.
///
/// Blood pressure contributes its systolic number (`TrendMeasurement.primary`): one line per
/// metric is the whole idea of the card, so the pair has to reduce to the number the reading is
/// named by.
///
/// A metric with no reading in the window produces no series at all, so every entry the card
/// shows can promise a real minimum and maximum. Series come back in `VitalType` order, which is
/// what keeps a metric's colour from changing between two loads of the same screen.
public func metricOverlayOf(
    _ measurements: [TrendMeasurement],
    days: ClosedRange<Int>
) -> MetricOverlay {
    let bucket = bucketFor(days)
    return MetricOverlay(
        series: VitalType.allCases.compactMap { type in
            overlaySeriesOrNull(measurements, type: type, days: days, bucket: bucket)
        },
        bucket: bucket
    )
}

/// How finely a window of `days` is sampled (`Overlay.kt:102-103`).
///
/// The chart draws the whole selected period rather than a scrollable slice of it, so the sampling
/// has to answer for the whole period too: a year at one point per day is 365 points on a card
/// three hundred pixels wide, which draws as noise and hides the very shape the card exists to
/// show. A week per point keeps a year at fifty-two points — the same granularity the dose card
/// already uses, so the two cards read against each other.
private func bucketFor(_ days: ClosedRange<Int>) -> OverlayBucket {
    if days.count <= maxDailyOverlayDays {
        return .daily
    }
    return .weekly
}

/// The longest window still worth a point per day. A month of daily points is legible; a quarter
/// is not (`Overlay.kt:106`).
let maxDailyOverlayDays = 31

/// The overlay the trends screen shows, or `nil` when there is nothing to overlay (`Overlay.kt:116-117`).
///
/// Fewer than `minOverlaySeries` metrics is not an overlay: laying a metric over itself shows
/// nothing the vitals screen does not already show, on an axis this card deliberately strips of
/// numbers. `nil` rather than a one-series `MetricOverlay`, so the screen physically cannot build
/// that card — the same shape `timeOfDayBreakdownOrNull` uses for the same reason.
public func metricOverlayOrNull(
    _ measurements: [TrendMeasurement],
    days: ClosedRange<Int>
) -> MetricOverlay? {
    let overlay = metricOverlayOf(measurements, days: days)
    return overlay.series.count >= minOverlaySeries ? overlay : nil
}

/// Two lines are the fewest that can be compared with each other (`Overlay.kt:120`).
let minOverlaySeries = 2

/// The Monday an epoch day's week starts on (`Overlay.kt:141`).
///
/// Weeks start on Monday because that is what both locales this app ships in treat as the first
/// day. Ported from `DoseWeeks.kt:55`; Task 4 reuses it for the dose card, where the two
/// analyses' weeks have to line up to read against each other.
func weekStartOf(_ epochDay: Int) -> Int {
    epochDay - mod(epochDay + thursdayOffset, daysPerWeek)
}

/// `Int.mod` (`DoseWeeks.kt`) — a remainder that is always non-negative, unlike Swift's `%` which
/// takes the dividend's sign and would answer a negative start for a negative epoch day.
private func mod(_ dividend: Int, _ divisor: Int) -> Int {
    let remainder = dividend % divisor
    return remainder >= 0 ? remainder : remainder + divisor
}

private func overlaySeriesOrNull(
    _ measurements: [TrendMeasurement],
    type: VitalType,
    days: ClosedRange<Int>,
    bucket: OverlayBucket
) -> OverlaySeries? {
    // Same-day readings collapse to that day's average first, whatever the granularity. Averaging
    // the readings is the honest way to reduce a day that was measured three times, exactly as the
    // daily figure below averages its own readings rather than keeping the last one.
    let dailyAverages = measurements
        .filter { $0.type == type && days.contains($0.epochDay) }
        .reduce(into: [Int: [Double]]()) { buckets, measurement in
            buckets[measurement.epochDay, default: []].append(measurement.primary)
        }
        .map { epochDay, readings -> (epochDay: Int, value: Double) in
            (epochDay, readings.average)
        }
        .sorted { $0.epochDay < $1.epochDay }
    if dailyAverages.isEmpty {
        return nil
    }

    // Weekly points average the days, not the readings: a day measured three times must not
    // outweigh a day measured once, which is the same reason the daily figure is an average of
    // its own readings rather than the last one.
    let sampled: [(x: Int, value: Double)] = switch bucket {
    case .daily:
        dailyAverages.map { ($0.epochDay, $0.value) }

    case .weekly:
        dailyAverages
            .reduce(into: [Int: [Double]]()) { weeks, entry in
                weeks[weekStartOf(entry.epochDay), default: []].append(entry.value)
            }
            .map { weekStart, values -> (x: Int, value: Double) in
                (weekStart, values.average)
            }
            .sorted { $0.x < $1.x }
    }

    let values = sampled.map(\.value)
    let min = values.min() ?? 0
    let max = values.max() ?? 0
    let span = max - min

    let points = sampled.map { entry in
        // A span of zero is a metric that never moved, or one measured a single time. Half
        // height is the honest drawing of "no spread of its own"; dividing would be a crash,
        // and pinning it to the top or the bottom would read as an extreme it never had.
        let y = span == 0 ? flatSeriesY : Float((entry.value - min) / span)
        return OverlayPoint(xEpochDay: entry.x, y: y)
    }

    return OverlaySeries(
        type: type,
        points: points,
        min: min,
        max: max
    )
}

/// Where a series with no spread of its own is drawn: down the middle (`Overlay.kt:168`).
private let flatSeriesY: Float = 0.5

private let thursdayOffset = 3
private let daysPerWeek = 7

extension [Double] {
    /// The arithmetic mean of a non-empty list; the empty case is guarded by callers before use.
    fileprivate var average: Double {
        reduce(0, +) / Double(count)
    }
}
