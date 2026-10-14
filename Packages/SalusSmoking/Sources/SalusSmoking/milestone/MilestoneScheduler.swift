// `MilestoneScheduler.plan(input, nowMs, zone, limit)`, written from `smoking-domain-contract.md` §4
// as amended by §8.8 and §8.9 in `salus-android` (the cross-platform source of truth; iOS-M17 plan,
// ruling P1). Pure: the reminder engine diffs the result against what it has scheduled, and at fire
// time asks for the plan again and drops a key that is no longer produced (reset, mode switch, slip).
//
// No `Calendar` here: an instant becomes a wall-clock reading through `Date.wallClock(in:)` and a
// wall-clock reading becomes an instant through `LocalDateTime.instant(in:)` (SalusCommon). Every
// duration is a difference of epoch milliseconds (contract §3.16), so `Days(n)` is `n` x 24 h and
// does not follow a daylight-saving change.

import Foundation
import SalusCommon
import SalusModel

/// What a planned notification announces. The golden vectors write these as `STAGE:h_20m`,
/// `DAYS:7`, `UNITS:100`, `MONEY:50000` and `EVENING:20380`.
public enum MilestoneKind: Sendable, Hashable {
    case stage(String)
    case days(Int64)
    case units(Int64)
    case money(Int64)
    case evening(Int64)
}

/// One local notification. `key` is stable per day (`q:<attemptId>:<yyyy-MM-dd>`, plus `:early` on
/// the first of a split first-48 h day; `r:<planId>:<yyyy-MM-dd>` for a REDUCE evening) so the
/// reminder engine can diff plans.
public struct PlannedNotification: Sendable, Equatable {
    public let key: String
    public let triggerAtMs: Int64
    public let kinds: [MilestoneKind]

    public init(key: String, triggerAtMs: Int64, kinds: [MilestoneKind]) {
        self.key = key
        self.triggerAtMs = triggerAtMs
        self.kinds = kinds
    }
}

public enum MilestoneScheduler {
    /// A background resync cannot ask for more than this many notifications. The platform's pending
    /// budget is 64, so the cap is far above any real call, and it keeps `limit = Int.max` from
    /// wrapping `Int64` in the day-milestone horizon or building billions of candidates (Android's
    /// `Long` horizon has the same hole; the contract leaves it silent).
    static let maximumLimit = 1000

    public static func plan(
        _ input: SmokingInput,
        nowMs: Int64,
        zone: TimeZone,
        limit: Int = 20
    ) -> [PlannedNotification] {
        // A resync runs in the background, so a non-positive limit plans nothing instead of trapping.
        guard limit > 0, let plan = input.plan else { return [] }
        let cap = min(limit, maximumLimit)
        let planned: [PlannedNotification] = switch plan.mode {
        case .quit:
            plan.notificationsEnabled ? quit(plan, input, nowMs: nowMs, zone: zone, limit: cap) : []
        case .reduce:
            // §8.9: evening planning depends on its own switch alone.
            plan.eveningReminderEnabled ? evenings(plan, nowMs: nowMs, zone: zone) : []
        }
        return Array(planned.prefix(cap))
    }
}

// MARK: - Constants

private let msPerDay: Int64 = 86_400_000
private let minorPerMajor: Int64 = 100
private let yearDays: Int64 = 365
private let eveningDays: Int64 = 7
private let firstHoursMs: Int64 = 48 * 3_600_000
private let minutesPerHour = 60
private let quietStartMinute = 22 * minutesPerHour
private let quietEndMinute = 8 * minutesPerHour
private let eveningMinute = 20 * minutesPerHour + 30

// MARK: - QUIT

private struct Candidate {
    let kind: MilestoneKind
    let atMs: Int64
}

/// A candidate with the instant it may fire at, after the quiet-hours shift.
private struct Due {
    let candidate: Candidate
    let firesAtMs: Int64
}

private func quit(
    _ plan: SmokingPlan,
    _ input: SmokingInput,
    nowMs: Int64,
    zone: TimeZone,
    limit: Int
) -> [PlannedNotification] {
    // The snapshot picks the active attempt and does the contract's figures (rules 4, 7, 9), so the
    // scheduler cannot disagree with the screen about what is already reached.
    guard case let .quit(snapshot) = SmokingStatsCalculator.snapshot(input, nowMs: nowMs, zone: zone),
          let attempt = input.attempts.first(where: { $0.id == snapshot.attemptId })
    else {
        return []
    }
    let baseline = plan.baselineUnitsPerDay
    let slips = (groupByOwningAttempt(input.events, attempts: input.attempts)[attempt.id] ?? [])
        .filter { $0.type == .smoked }
    // Rule 9: stages count from the later of the attempt start and the latest slip.
    let anchorMs = max(attempt.startedAtMs, slips.map(\.occurredAtMs).max() ?? attempt.startedAtMs)

    let prices = input.prices.sorted { $0.effectiveFromEpochDay < $1.effectiveFromEpochDay }
    let todayCost = unitCost(on: epochDay(of: nowMs, in: zone), ascendingPrices: prices)

    let candidates = stages(anchorMs: anchorMs)
        + days(startMs: attempt.startedAtMs, nowMs: nowMs, limit: limit)
        + units(notSmoked: snapshot.unitsNotSmoked, baseline: baseline, nowMs: nowMs)
        + money(
            currency: plan.currencyCode,
            savedMinor: snapshot.savedMinor,
            minorPerDay: saturatingMultiply(baseline, todayCost),
            nowMs: nowMs
        )

    // A kind whose instant is not strictly after now is already reached, so it is skipped. Instants
    // move out of quiet hours first, then group by the local day they fire on.
    let dues = candidates
        .filter { $0.atMs > nowMs }
        .map { Due(candidate: $0, firesAtMs: outOfQuietHours($0.atMs, zone: zone)) }
    let byDay = Dictionary(grouping: dues) { localDate(of: $0.firesAtMs, zone: zone) }
    let firstHoursEndMs = saturatingAdd(attempt.startedAtMs, firstHoursMs)

    return byDay.keys.sorted().flatMap { date -> [PlannedNotification] in
        let epochDay = Int64(date.epochDay)
        // §8.8: a day that overlaps `[start, start + 48 h)` may carry two notifications.
        let overlapsFirstHours = startOfDayMs(epochDay: epochDay, in: zone) < firstHoursEndMs
            && startOfDayMs(epochDay: epochDay + 1, in: zone) > attempt.startedAtMs
        return notificationsOfDay(
            key: "q:\(attempt.id):\(isoText(date))",
            sameDay: byDay[date] ?? [],
            splitEarliest: overlapsFirstHours
        )
    }
}

/// Contract §4 as amended (§8.8): a notification fires at the latest instant among its kinds, so
/// nothing is announced before it is true. A day overlapping the first 48 h may instead carry two:
/// an `:early` one at its earliest instant with every kind due then, and one at its latest instant
/// with the rest. A day whose kinds share one instant always carries one.
private func notificationsOfDay(key: String, sameDay: [Due], splitEarliest: Bool) -> [PlannedNotification] {
    guard let earliestMs = sameDay.map(\.firesAtMs).min() else { return [] }
    let early = sameDay.filter { $0.firesAtMs == earliestMs }
    let rest = sameDay.filter { $0.firesAtMs != earliestMs }
    guard splitEarliest, !rest.isEmpty else { return [notification(key: key, dues: sameDay)] }
    return [notification(key: "\(key):early", dues: early), notification(key: key, dues: rest)]
}

/// Kinds are ordered by each kind's own instant before the quiet-hours shift (§8.9); a tie reads in
/// the order the contract lists the kinds.
private func notification(key: String, dues: [Due]) -> PlannedNotification {
    let ordered = dues.map(\.candidate).sorted {
        ($0.atMs, $0.kind.rank) < ($1.atMs, $1.kind.rank)
    }
    return PlannedNotification(
        key: key,
        triggerAtMs: dues.map(\.firesAtMs).max() ?? 0,
        kinds: ordered.map(\.kind)
    )
}

extension MilestoneKind {
    /// Same-instant kinds read Stage, Days, Units, Money, Evening.
    fileprivate var rank: Int {
        switch self {
        case .stage: 0
        case .days: 1
        case .units: 2
        case .money: 3
        case .evening: 4
        }
    }
}

private func stages(anchorMs: Int64) -> [Candidate] {
    MilestoneCatalog.healthStages.map {
        Candidate(kind: .stage($0.id), atMs: saturatingAdd(anchorMs, $0.thresholdMs))
    }
}

/// Day milestones count from the attempt start in fixed 24 h days (durations are epoch-ms
/// differences, contract §3.16). Each lands on its own local day, so `limit + 1` future ones are
/// enough for the nearest `limit` notifications; the horizon guarantees that many.
private func days(startMs: Int64, nowMs: Int64, limit: Int) -> [Candidate] {
    let elapsedDays = max(0, nowMs - startMs) / msPerDay
    let horizon = saturatingAdd(elapsedDays, yearDays * (Int64(limit) + 1))
    return MilestoneCatalog.dayMilestones(upTo: horizon).map {
        Candidate(kind: .days($0), atMs: saturatingAdd(startMs, saturatingMultiply($0, msPerDay)))
    }
}

/// Projected from the current floored figure at `baseline` units a day (§8.9). A zero baseline
/// plans none: the contract keeps it at 1 or more, but a corrupt row must not divide by zero in a
/// background resync.
private func units(notSmoked: Int64, baseline: Int64, nowMs: Int64) -> [Candidate] {
    guard baseline > 0 else { return [] }
    return MilestoneCatalog.unitMilestones
        .filter { $0 > notSmoked }
        .map { Candidate(kind: .units($0), atMs: saturatingAdd(nowMs, ($0 - notSmoked) * msPerDay / baseline)) }
}

/// Projected from the current saving at `baseline x unitCost(today)` a day (§8.9); a free unit
/// never saves, so a zero rate plans none.
private func money(currency: String, savedMinor: Int64, minorPerDay: Int64, nowMs: Int64) -> [Candidate] {
    guard minorPerDay > 0 else { return [] }
    return MoneySteps.forCurrency(currency)
        .map { saturatingMultiply($0, minorPerMajor) }
        .filter { $0 > savedMinor }
        .map {
            let waitMs = saturatingMultiply($0 - savedMinor, msPerDay) / minorPerDay
            return Candidate(kind: .money($0), atMs: saturatingAdd(nowMs, waitMs))
        }
}

// MARK: - REDUCE

/// 20:30 on today and the six days after it (§8.9). Whether a day already has an entry is decided
/// at fire time, because the user can still log one after this plan is made.
private func evenings(_ plan: SmokingPlan, nowMs: Int64, zone: TimeZone) -> [PlannedNotification] {
    let today = Int64(localDate(of: nowMs, zone: zone).epochDay)
    return (today ..< today + eveningDays).compactMap { epochDay in
        let date = LocalDate(epochDay: Int(epochDay))
        let atMs = LocalDateTime(date: date, minuteOfDay: eveningMinute).instant(in: zone).epochMilliseconds
        guard atMs > nowMs else { return nil }
        return PlannedNotification(key: "r:\(plan.id):\(isoText(date))", triggerAtMs: atMs, kinds: [.evening(epochDay)])
    }
}

// MARK: - Time

/// Quiet hours are 22:00 to 08:00 local: an instant inside them moves to the next 08:00, which may
/// be the next day.
private func outOfQuietHours(_ atMs: Int64, zone: TimeZone) -> Int64 {
    let local = Date(epochMilliseconds: atMs).wallClock(in: zone)
    let date: LocalDate
    if local.minuteOfDay >= quietStartMinute {
        date = local.date.plusDays(1)
    } else if local.minuteOfDay < quietEndMinute {
        date = local.date
    } else {
        return atMs
    }
    return LocalDateTime(date: date, minuteOfDay: quietEndMinute).instant(in: zone).epochMilliseconds
}

private func localDate(of epochMs: Int64, zone: TimeZone) -> LocalDate {
    Date(epochMilliseconds: epochMs).wallClock(in: zone).date
}

/// `yyyy-MM-dd`, the date part of a key.
private func isoText(_ date: LocalDate) -> String {
    func padded(_ value: Int, _ width: Int) -> String {
        let text = String(value)
        return String(repeating: "0", count: max(0, width - text.count)) + text
    }
    return "\(padded(date.year, 4))-\(padded(date.month, 2))-\(padded(date.day, 2))"
}

// MARK: - Overflow-safe arithmetic

private func saturatingMultiply(_ lhs: Int64, _ rhs: Int64) -> Int64 {
    let (product, overflow) = lhs.multipliedReportingOverflow(by: rhs)
    return overflow ? Int64.max : product
}

private func saturatingAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
    let (sum, overflow) = lhs.addingReportingOverflow(rhs)
    return overflow ? Int64.max : sum
}
