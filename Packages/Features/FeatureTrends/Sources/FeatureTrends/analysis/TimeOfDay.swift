// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/analysis/TimeOfDay.kt`.

import SalusModel

/// The four parts of the day a measurement can fall into (`TimeOfDay.kt:20-25`).
///
/// Bounds are minutes of the local day and half-open, `[fromMinute, untilMinute)`, so every
/// minute belongs to exactly one part and no reading can be counted twice. `night` is the one
/// that wraps midnight: a 23:30 reading and a 01:30 reading are the same bedtime habit, and
/// splitting them across two buckets would hide it.
///
/// The boundaries are meal- and sleep-shaped rather than clock-quarter-shaped, because that is
/// what makes a blood pressure or glucose pattern readable: mornings before the day starts,
/// midday around lunch, evening after dinner, night around sleep.
public enum DayPart: CaseIterable, Equatable, Hashable, Sendable {
    case morning
    case midday
    case evening
    case night

    /// `TimeOfDay.kt:20-25` — the half-open minute range, `[fromMinute, untilMinute)`.
    public var fromMinute: Int {
        switch self {
        case .morning: 300
        case .midday: 720
        case .evening: 1020
        case .night: 1320
        }
    }

    public var untilMinute: Int {
        switch self {
        case .morning: 720
        case .midday: 1020
        case .evening: 1320
        case .night: 300
        }
    }
}

extension DayPart {
    /// True when `minuteOfDay` falls in this part; the only place the midnight wrap is handled
    /// (`TimeOfDay.kt:28-33`).
    public func contains(minuteOfDay: Int) -> Bool {
        if fromMinute < untilMinute {
            minuteOfDay >= fromMinute && minuteOfDay < untilMinute
        } else {
            minuteOfDay >= fromMinute || minuteOfDay < untilMinute
        }
    }
}

/// What one `DayPart` amounts to over a window (`TimeOfDay.kt:43-48`).
///
/// The averages are nullable rather than zero: nobody's blood pressure is 0, so a part with no
/// reading has to be distinguishable from one with a low reading. `secondaryAverage` is filled
/// only for types that carry a second number — diastolic for blood pressure — and is `nil`
/// everywhere else.
public struct DayPartStats: Equatable, Sendable {
    public let part: DayPart
    public let count: Int
    public let primaryAverage: Double?
    public let secondaryAverage: Double?

    public init(part: DayPart, count: Int, primaryAverage: Double?, secondaryAverage: Double?) {
        self.part = part
        self.count = count
        self.primaryAverage = primaryAverage
        self.secondaryAverage = secondaryAverage
    }
}

/// One metric's day, in four buckets (`TimeOfDay.kt:56-59`).
///
/// Carries plain numbers only: no chart model, no UI type. The screen maps this to
/// `BarChartUiModel` at the UI edge, which is what keeps the analysis portable to iOS.
public struct TimeOfDayBreakdown: Equatable, Sendable {
    public let type: VitalType
    public let parts: [DayPartStats]

    public init(type: VitalType, parts: [DayPartStats]) {
        self.type = type
        self.parts = parts
    }
}

/// Buckets `measurements` of `type` by the part of the day they were taken in
/// (`TimeOfDay.kt:71-87`).
///
/// Pure and total: all four parts always come back, in `DayPart.allCases` order, so the caller
/// renders a fixed set of columns and an unmeasured part shows as an absent one rather than as
/// a missing axis label.
///
/// Measurements of any other type are ignored — the window carries every vital the user logs,
/// and averaging a weight in kilograms into a glucose figure would be nonsense.
public func timeOfDayBreakdownOf(
    _ measurements: [TrendMeasurement],
    type: VitalType
) -> TimeOfDayBreakdown {
    let ofType = measurements.filter { $0.type == type }
    let parts = DayPart.allCases.map { part in
        let inPart = ofType.filter { part.contains(minuteOfDay: $0.minuteOfDay) }
        let secondaries = inPart.compactMap(\.secondary)
        return DayPartStats(
            part: part,
            count: inPart.count,
            primaryAverage: inPart.map(\.primary).averageOrNil(),
            secondaryAverage: secondaries.averageOrNil()
        )
    }
    return TimeOfDayBreakdown(type: type, parts: parts)
}

/// The breakdown the trends screen shows, or `nil` when the window holds neither metric
/// (`TimeOfDay.kt:99-102`).
///
/// One card, one metric: blood pressure wins when both were logged, because it is the richer
/// reading and the one whose time-of-day pattern people are actually told to watch. Weight is
/// not a candidate at all — when you step on the scale says nothing about your weight.
///
/// `nil` rather than an empty breakdown, so a screen physically cannot draw a card with no
/// bars in it.
public func timeOfDayBreakdownOrNull(_ measurements: [TrendMeasurement]) -> TimeOfDayBreakdown? {
    timeOfDayMetrics
        .first { type in measurements.contains { $0.type == type } }
        .map { type in timeOfDayBreakdownOf(measurements, type: type) }
}

/// Candidate metrics, most preferred first (`TimeOfDay.kt:105`).
private let timeOfDayMetrics: [VitalType] = [.bloodPressure, .bloodGlucose]

extension [Double] {
    /// `List<Double>.averageOrNull()` (`TimeOfDay.kt:107`) — `nil` for an empty list.
    fileprivate func averageOrNil() -> Double? {
        isEmpty ? nil : reduce(0, +) / Double(count)
    }
}
