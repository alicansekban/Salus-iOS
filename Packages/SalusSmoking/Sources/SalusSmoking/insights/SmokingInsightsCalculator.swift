// Premium Trends figures and the AI aggregate, written from `smoking-domain-contract.md` section 5
// in `salus-android`, as clarified by section 8.7 (Android twin: `SmokingInsightsCalculator.kt`).
// Pure: the only clock is the `nowMs` argument and the only zone is the `zone` argument.
//
// Events are bucketed by their stored `epochDay` (section 8.5) and their local hour is read in
// their own `tzId`, so a heatmap row and column come from one zone and do not depend on the device.
// `zone` is used for what no record stores: "today", the setup day, the day an attempt started,
// and the hour of an event whose `tzId` is unknown. An instant becomes a day only through
// `SalusCommon`'s `epochDay(of:in:)`; the event's hour is a plain offset computation, so no
// `Calendar` is needed here.

import Foundation
import SalusCommon

public enum SmokingInsightsCalculator {
    /// Days of history the minimum-data rule and the heatmap look at by default (contract section 5).
    public static let defaultWindowDays = 30

    public static func insights(
        _ input: SmokingInput,
        nowMs: Int64,
        zone: TimeZone,
        windowDays: Int = defaultWindowDays
    ) -> SmokingInsights {
        guard let plan = input.plan else {
            return emptyInsights()
        }
        let today = epochDay(of: nowMs, in: zone)
        let from = today - Int64(max(1, windowDays)) + 1
        let events = input.events.filter { $0.epochDay >= from && $0.epochDay <= today }
        let occurrences = events.filter(isOccurrence)
        let heatmap = heatmap(of: occurrences, zone: zone)
        let busiest = busiestBand(in: heatmap)
        let attempts = input.attempts.enumerated()
            .sorted { ($0.element.startedAtMs, $0.offset) < ($1.element.startedAtMs, $1.offset) }
            .map(\.element)
        return SmokingInsights(
            hasEnoughData: Set(events.map(\.epochDay)).count >= minDaysForInsights,
            triggers: triggerShares(of: occurrences),
            heatmap: heatmap,
            busiestBand: busiest?.band,
            busiestBandPermille: busiest?.permille ?? 0,
            reductionWeekly: plan.mode == .reduce
                ? reductionWeekly(input.events, setupDay: epochDay(of: plan.createdAtMs, in: zone))
                : [],
            attemptDurations: attempts.map {
                AttemptDuration(attemptId: $0.id, durationMs: max(0, ($0.endedAtMs ?? nowMs) - $0.startedAtMs))
            },
            quitMarkerEpochDays: attempts.map { epochDay(of: $0.startedAtMs, in: zone) }
        )
    }

    /// The aggregate the AI summary may use for `fromEpochDay ... toEpochDay` (inclusive); nil when
    /// nothing is set up. It reads only what `SmokingAiStats` declares.
    public static func aiStats(
        _ input: SmokingInput,
        fromEpochDay: Int64,
        toEpochDay: Int64,
        zone: TimeZone
    ) -> SmokingAiStats? {
        guard let plan = input.plan else { return nil }
        // Nothing from before the setup day feeds any field, so a back-dated event cannot skew the
        // summary (section 8.7).
        let trackedFrom = max(fromEpochDay, epochDay(of: plan.createdAtMs, in: zone))
        let events = input.events.filter { $0.epochDay >= trackedFrom && $0.epochDay <= toEpochDay }
        let occurrences = events.filter(isOccurrence)
        return SmokingAiStats(
            mode: plan.mode,
            daysTracked: Int(max(0, toEpochDay - trackedFrom + 1)),
            // A zero-unit REDUCE marker records "none today"; counting it as a slip would tell the
            // summary the user smoked on a day they logged none.
            slipCount: events.filter { $0.type == .smoked && ($0.units ?? 0) > 0 }.count,
            topTriggers: Array(triggerShares(of: occurrences).prefix(topTriggerCount)),
            busiestBand: busiestBand(in: heatmap(of: occurrences, zone: zone))?.band,
            reductionPercent: plan.mode == .reduce
                ? reductionPercent(events, baseline: plan.baselineUnitsPerDay)
                : nil
        )
    }
}

// MARK: - Constants

private let minDaysForInsights = 7
private let daysPerBucket: Int64 = 7
private let weekdayCount = 7
private let topTriggerCount = 3
private let permille: Int64 = 1000
private let msPerHour: Int64 = 3_600_000
private let msPerDay: Int64 = 86_400_000
/// 1970-01-01 was a Thursday, the fourth ISO weekday: `(epochDay + 3) mod 7` is the 0-based
/// Monday-first column.
private let epochDayWeekdayShift: Int64 = 3

// MARK: - Pieces

private func emptyInsights() -> SmokingInsights {
    SmokingInsights(
        hasEnoughData: false,
        triggers: [],
        heatmap: Array(repeating: Array(repeating: 0, count: weekdayCount), count: HourBand.allCases.count),
        busiestBand: nil,
        busiestBandPermille: 0,
        reductionWeekly: [],
        attemptDurations: [],
        quitMarkerEpochDays: []
    )
}

/// A moment the user smoked or resisted. The zero-unit REDUCE marker records "none today"; its
/// `occurredAtMs` is when it was logged, so it feeds neither the heatmap nor the trigger shares (it
/// still counts as a logged day for `hasEnoughData` and the reduction figures). Section 8.7.
private func isOccurrence(_ event: SmokingEvent) -> Bool {
    !(event.type == .smoked && event.units == 0)
}

/// Share per trigger, biggest first; equal counts keep the enum's declaration order. The share is
/// floored, so shares may sum to 999 (section 8.7).
private func triggerShares(of events: [SmokingEvent]) -> [TriggerShare] {
    var counts: [CravingTrigger: Int] = [:]
    for trigger in events.compactMap(\.trigger) {
        counts[trigger, default: 0] += 1
    }
    let total = Int64(counts.values.reduce(0, +))
    let order = CravingTrigger.allCases
    return counts
        .sorted { lhs, rhs in
            lhs.value != rhs.value
                ? lhs.value > rhs.value
                : (order.firstIndex(of: lhs.key) ?? 0) < (order.firstIndex(of: rhs.key) ?? 0)
        }
        .map { TriggerShare(trigger: $0.key, count: $0.value, permille: Int(Int64($0.value) * permille / total)) }
}

private func heatmap(of events: [SmokingEvent], zone: TimeZone) -> [[Int]] {
    var cells = Array(repeating: Array(repeating: 0, count: weekdayCount), count: HourBand.allCases.count)
    for event in events {
        // Row and column both come from the event's own zone: the stored `epochDay` is that zone's
        // date (section 8.5), so the hour has to be read there too.
        let band = bandIndex(forHour: localHour(of: event, fallback: zone))
        let weekday = Int(floorMod(event.epochDay + epochDayWeekdayShift, Int64(weekdayCount)))
        cells[band][weekday] += 1
    }
    return cells
}

/// The hour (0-23) the event's instant shows on a wall clock in its own zone, or in `fallback` when
/// the stored identifier is not a zone this device knows.
private func localHour(of event: SmokingEvent, fallback: TimeZone) -> Int {
    let zone = TimeZone(identifier: event.tzId) ?? fallback
    let offsetMs = Int64(zone.secondsFromGMT(for: Date(timeIntervalSince1970: Double(event.occurredAtMs) / 1000))) *
        1000
    return Int(floorMod(event.occurredAtMs + offsetMs, msPerDay) / msPerHour)
}

private func floorMod(_ value: Int64, _ divisor: Int64) -> Int64 {
    let remainder = value % divisor
    return remainder < 0 ? remainder + divisor : remainder
}

/// 08-09, 10-11, 12-13, 14-15, 16-17, 18-21 and everything else (22:00-07:59) in `HourBand` order.
private func bandIndex(forHour hour: Int) -> Int {
    switch hour {
    case 8 ... 9: 0
    case 10 ... 11: 1
    case 12 ... 13: 2
    case 14 ... 15: 3
    case 16 ... 17: 4
    case 18 ... 21: 5
    default: 6
    }
}

/// The row with the most events (a tie goes to the earlier row) and its permille of the total.
private func busiestBand(in heatmap: [[Int]]) -> (band: HourBand, permille: Int)? {
    let rowTotals = heatmap.map { $0.reduce(0, +) }
    let total = Int64(rowTotals.reduce(0, +))
    guard total > 0, let best = rowTotals.max(), let index = rowTotals.firstIndex(of: best) else { return nil }
    return (HourBand.allCases[index], Int(Int64(best) * permille / total))
}

/// Units per logged day; a day with only a zero-unit marker is logged with 0.
private func loggedUnitsByDay(_ events: [SmokingEvent]) -> [Int64: Int64] {
    var units: [Int64: Int64] = [:]
    for event in events where event.type == .smoked {
        guard let eventUnits = event.units else { continue }
        units[event.epochDay, default: 0] += eventUnits
    }
    return units
}

/// 7-day buckets counted from `setupDay`, each the average units per logged day, rounded down.
/// Every day with a SMOKED event counts as logged, the zero-unit marker included (section 3.12).
/// Nil marks a bucket in between without a logged day; the list ends at the last bucket with data.
private func reductionWeekly(_ events: [SmokingEvent], setupDay: Int64) -> [Int64?] {
    let unitsByDay = loggedUnitsByDay(events.filter { $0.epochDay >= setupDay })
    guard !unitsByDay.isEmpty else { return [] }
    var byBucket: [Int64: [Int64]] = [:]
    for (day, units) in unitsByDay {
        byBucket[(day - setupDay) / daysPerBucket, default: []].append(units)
    }
    let lastBucket = byBucket.keys.max() ?? 0
    return (0 ... lastBucket).map { bucket in
        byBucket[bucket].map { $0.reduce(0, +) / Int64($0.count) }
    }
}

/// `100 - avgLoggedUnits x 100 / baseline` over the logged days, as one integer division. Not
/// clamped (section 8.7).
private func reductionPercent(_ events: [SmokingEvent], baseline: Int64) -> Int? {
    let unitsByDay = loggedUnitsByDay(events)
    guard !unitsByDay.isEmpty, baseline > 0 else { return nil }
    let (scaledTotal, overflow) = unitsByDay.values.reduce(0, +).multipliedReportingOverflow(by: 100)
    let (denominator, denominatorOverflow) = Int64(unitsByDay.count).multipliedReportingOverflow(by: baseline)
    guard !overflow, !denominatorOverflow else { return nil }
    return Int(100 - scaledTotal / denominator)
}
