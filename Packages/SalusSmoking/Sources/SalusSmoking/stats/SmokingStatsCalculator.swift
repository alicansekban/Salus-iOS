// `SmokingStatsCalculator.snapshot(input, nowMs, zone)`, written from the numbered rules of
// `smoking-domain-contract.md` §3 in `salus-android` (the cross-platform source of truth). Rule
// numbers in the comments below are that section's. Pure: no clock, no I/O, no Calendar — an
// instant becomes a day only through `SalusCommon`'s `epochDay(of:in:)` / `startOfDayMs`.
//
// All arithmetic is 64-bit and overflow-safe: a product that would leave `Int64` saturates at
// `Int64.max` instead of trapping, so a corrupt row cannot crash the app (a 20-year horizon at
// 60 a day and 10 000 minor units needs about 4.4e9 and never gets near the limit).

import Foundation
import SalusCommon

public enum SmokingStatsCalculator {
    public static func snapshot(_ input: SmokingInput, nowMs: Int64, zone: TimeZone) -> SmokingSnapshot {
        // Rule 1: no plan means nothing to compute.
        guard let plan = input.plan else {
            return .notSetUp
        }
        let context = Context(input: input, plan: plan, nowMs: nowMs, zone: zone)
        switch plan.mode {
        case .quit:
            return quitSnapshot(context)
        case .reduce:
            return .reduce(reduceSnapshot(context))
        }
    }
}

// MARK: - Shared context

private let msPerDay: Int64 = 86_400_000
private let msPerMinute: Int64 = 60000
private let minutesRegainedPerUnit: Int64 = 11
private let countingAgainFloorMs: Int64 = 72 * 3_600_000

private struct Context {
    let input: SmokingInput
    let plan: SmokingPlan
    let nowMs: Int64
    let zone: TimeZone
    /// Ascending by effective day, so the lookup below can stop at the first later one.
    let prices: [PricePeriod]
    /// Each event grouped under the attempt that owns it (rule 3, contract section 8.1).
    let eventsByAttempt: [String: [SmokingEvent]]

    init(input: SmokingInput, plan: SmokingPlan, nowMs: Int64, zone: TimeZone) {
        self.input = input
        self.plan = plan
        self.nowMs = nowMs
        self.zone = zone
        prices = input.prices.sorted { $0.effectiveFromEpochDay < $1.effectiveFromEpochDay }
        eventsByAttempt = groupByOwningAttempt(input.events, attempts: input.attempts)
    }

    var baseline: Int64 {
        plan.baselineUnitsPerDay
    }

    var isVape: Bool {
        plan.productType == .vape
    }

    /// Rule 6: the latest period with `effectiveFrom <= day`; with none, the earliest period's price.
    func unitCost(on day: Int64) -> Int64 {
        SalusSmoking.unitCost(on: day, ascendingPrices: prices)
    }

    func day(of epochMs: Int64) -> Int64 {
        epochDay(of: epochMs, in: zone)
    }
}

/// Rule 6, shared with the milestone scheduler so the two cannot read a price differently: the
/// latest period with `effectiveFrom <= day`; with none, the earliest period's price; with no period
/// at all, 0 (contract section 8.5). `ascendingPrices` is sorted by `effectiveFromEpochDay`.
func unitCost(on day: Int64, ascendingPrices: [PricePeriod]) -> Int64 {
    var chosen = ascendingPrices.first
    for period in ascendingPrices {
        guard period.effectiveFromEpochDay <= day else { break }
        chosen = period
    }
    return chosen?.unitCostMinor ?? 0
}

// MARK: - Overflow-safe arithmetic

/// `a * b`, saturating. Every operand in this file is non-negative.
private func saturatingMultiply(_ lhs: Int64, _ rhs: Int64) -> Int64 {
    let (product, overflow) = lhs.multipliedReportingOverflow(by: rhs)
    return overflow ? Int64.max : product
}

private func saturatingAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
    let (sum, overflow) = lhs.addingReportingOverflow(rhs)
    return overflow ? Int64.max : sum
}

/// `lhs * rhs / divisor` with 64-bit integer (truncating) division.
private func scaled(_ lhs: Int64, _ rhs: Int64, by divisor: Int64) -> Int64 {
    saturatingMultiply(lhs, rhs) / divisor
}

// MARK: - QUIT

private func quitSnapshot(_ context: Context) -> SmokingSnapshot {
    // The latest open attempt. Repair on load (contract §6) guarantees one for a QUIT plan; if it
    // could not, rule 1 says the user is not set up.
    guard let active = context.input.attempts.filter({ $0.endedAtMs == nil })
        .max(by: { $0.startedAtMs < $1.startedAtMs })
    else {
        return .notSetUp
    }
    let now = context.nowMs
    let slips = slips(of: active, in: context)

    // Rule 2: everything clamps at zero when the device clock is behind the start.
    let elapsed = max(0, now - active.startedAtMs)
    let latestSlip = slips.map(\.occurredAtMs).max() ?? active.startedAtMs
    // Rule 9.
    let sinceLastSmoke = max(0, now - max(active.startedAtMs, latestSlip))

    // Rule 4.
    let slipUnits = totalUnits(of: slips)
    let unitsNotSmoked = max(0, scaled(elapsed, context.baseline, by: msPerDay) - slipUnits)

    // Rule 5: today's local overlap with the attempt, less today's slips.
    let today = context.day(of: now)
    let todayStart = startOfDayMs(epochDay: today, in: context.zone)
    let todayOverlap = max(0, now - max(active.startedAtMs, todayStart))
    let todaySlipUnits = totalUnits(of: slips.filter { $0.epochDay == today })
    let unitsNotSmokedToday = max(0, scaled(todayOverlap, context.baseline, by: msPerDay) - todaySlipUnits)

    // Rule 7.
    let saved = savedMinor(from: active.startedAtMs, to: now, slips: slips, in: context)

    let stages = stageProgress(sinceLastSmokeMs: sinceLastSmoke, attemptElapsedMs: elapsed)

    let events = context.input.events
    let cravingsInAttempt = cravings(of: active, in: context).count
    let cravingsAllTime = events.filter { $0.type == .cravingResisted }.count

    return .quit(
        QuitSnapshot(
            plan: context.plan,
            attemptId: active.id,
            attemptStartedAtMs: active.startedAtMs,
            attemptElapsedMs: elapsed,
            sinceLastSmokeMs: sinceLastSmoke,
            slipCount: slips.count,
            unitsNotSmoked: unitsNotSmoked,
            unitsNotSmokedToday: unitsNotSmokedToday,
            savedMinor: saved,
            // Rule 8.
            timeRegainedMinutes: context.isVape ? nil : saturatingMultiply(unitsNotSmoked, minutesRegainedPerUnit),
            cravingsBeaten: cravingsInAttempt,
            cravingsBeatenAllTime: cravingsAllTime,
            stages: stages,
            nextStage: stages.first { $0.state == .inProgress },
            attempts: attemptSummaries(context),
            goal: goalProgress(context)
        )
    )
}

/// Rule 3, contract section 8.1. The stored `attemptId` is authoritative: a restart slip sits
/// exactly on the instant the old attempt closes and the new one opens, and it stays on the old one
/// (contract section 6, `ResolveSlip`). Only an event with no usable link (nil, or an id that names
/// no attempt) falls back to the latest-starting attempt whose `[start, end)` contains it. Either
/// way an event before its attempt's start belongs to no attempt: a back-dated entry is not a slip.
func groupByOwningAttempt(_ events: [SmokingEvent], attempts: [QuitAttempt]) -> [String: [SmokingEvent]] {
    let attemptsById = Dictionary(attempts.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    var grouped: [String: [SmokingEvent]] = [:]
    for event in events {
        let linked = event.attemptId.flatMap { attemptsById[$0] }
        let owner = linked ?? attempts
            .filter { event.occurredAtMs >= $0.startedAtMs && ($0.endedAtMs.map { event.occurredAtMs < $0 } ?? true) }
            .max { $0.startedAtMs < $1.startedAtMs }
        guard let owner, event.occurredAtMs >= owner.startedAtMs else { continue }
        grouped[owner.id, default: []].append(event)
    }
    return grouped
}

private func slips(of attempt: QuitAttempt, in context: Context) -> [SmokingEvent] {
    (context.eventsByAttempt[attempt.id] ?? []).filter { $0.type == .smoked }
}

/// Rule 11, with the same ownership as a slip.
private func cravings(of attempt: QuitAttempt, in context: Context) -> [SmokingEvent] {
    (context.eventsByAttempt[attempt.id] ?? []).filter { $0.type == .cravingResisted }
}

private func totalUnits(of events: [SmokingEvent]) -> Int64 {
    events.reduce(0) { saturatingAdd($0, $1.units ?? 0) }
}

/// Rule 7: the money not spent over `[from, to]`, less what the slips cost.
private func savedMinor(from: Int64, to: Int64, slips: [SmokingEvent], in context: Context) -> Int64 {
    max(0, accruedMoney(from: from, to: to, in: context) - slipDeduction(slips, in: context))
}

/// Rule 7: for each local calendar day overlapping `[from, to]`,
/// `overlapMs x baseline x unitCost(day) / 86 400 000`, divided per day.
///
/// The day's length is read from the zone (`startOfDayMs` of the next day), so a 23-hour
/// daylight-saving day contributes its 23 hours and no more (rule 16).
private func accruedMoney(from: Int64, to: Int64, in context: Context) -> Int64 {
    guard to > from else { return 0 }
    var total: Int64 = 0
    var day = context.day(of: from)
    let lastDay = context.day(of: to)
    var dayStart = startOfDayMs(epochDay: day, in: context.zone)
    while day <= lastDay {
        let nextStart = startOfDayMs(epochDay: day + 1, in: context.zone)
        let overlap = min(to, nextStart) - max(from, dayStart)
        if overlap > 0 {
            let units = saturatingMultiply(overlap, context.baseline)
            total = saturatingAdd(total, scaled(units, context.unitCost(on: day), by: msPerDay))
        }
        day += 1
        dayStart = nextStart
    }
    return total
}

/// Rule 7: each slip costs its units at its own day's price. VAPE has no per-unit meaning, so it is
/// one `unitCost(day)` per distinct slip day.
private func slipDeduction(_ slips: [SmokingEvent], in context: Context) -> Int64 {
    if context.isVape {
        return Set(slips.map(\.epochDay)).reduce(0) { saturatingAdd($0, context.unitCost(on: $1)) }
    }
    return slips.reduce(0) {
        saturatingAdd($0, saturatingMultiply($1.units ?? 0, context.unitCost(on: $1.epochDay)))
    }
}

// MARK: - Stages (rule 10)

private func stageProgress(sinceLastSmokeMs: Int64, attemptElapsedMs: Int64) -> [StageProgress] {
    var foundInProgress = false
    return HealthStage.catalog.map { stage in
        let threshold = stage.thresholdMs
        if sinceLastSmokeMs >= threshold {
            return StageProgress(stageId: stage.id, state: .done, permille: 1000, remainingMs: 0, countingAgain: false)
        }
        // Not done: a stage past 72 hours that the attempt itself outlived is being counted again
        // after a slip.
        let countingAgain = threshold > countingAgainFloorMs && attemptElapsedMs >= threshold
        let remaining = threshold - sinceLastSmokeMs
        if foundInProgress {
            return StageProgress(
                stageId: stage.id, state: .pending, permille: 0, remainingMs: remaining, countingAgain: countingAgain
            )
        }
        foundInProgress = true
        return StageProgress(
            stageId: stage.id,
            state: .inProgress,
            permille: Int(scaled(sinceLastSmokeMs, 1000, by: threshold)),
            remainingMs: remaining,
            countingAgain: countingAgain
        )
    }
}

/// REDUCE has no "since last smoke" clock: every stage is pending at zero.
private func stagesPreview() -> [StageProgress] {
    HealthStage.catalog.map {
        StageProgress(stageId: $0.id, state: .pending, permille: 0, remainingMs: $0.thresholdMs, countingAgain: false)
    }
}

// MARK: - Attempts (rule 15)

private func attemptSummaries(_ context: Context) -> [AttemptSummary] {
    let now = context.nowMs
    let ordered = context.input.attempts.enumerated()
        .sorted { ($0.element.startedAtMs, $0.offset) < ($1.element.startedAtMs, $1.offset) }
        .map(\.element)

    let durations = ordered.map { attempt -> Int64 in
        // A closed attempt is `end - start`; an open one runs to now.
        max(0, (attempt.endedAtMs ?? now) - attempt.startedAtMs)
    }
    let longest = durations.max() ?? 0
    // The earliest attempt wins a tie.
    let longestIndex = durations.firstIndex(of: longest)

    return ordered.enumerated().map { index, attempt in
        let slips = slips(of: attempt, in: context)
        let windowEnd = attempt.endedAtMs ?? now
        return AttemptSummary(
            id: attempt.id,
            ordinal: index + 1,
            startedAtMs: attempt.startedAtMs,
            endedAtMs: attempt.endedAtMs,
            durationMs: durations[index],
            slipCount: slips.count,
            savedMinor: savedMinor(from: attempt.startedAtMs, to: windowEnd, slips: slips, in: context),
            cravingsBeaten: cravings(of: attempt, in: context).count,
            isLongest: index == longestIndex
        )
    }
}

// MARK: - REDUCE (rules 12 and 13)

private func reduceSnapshot(_ context: Context) -> ReduceSnapshot {
    let today = context.day(of: context.nowMs)
    let smoked = context.input.events.filter { $0.type == .smoked }

    // A day's units are the sum of its SMOKED events; a day with none is absent from the map,
    // which is "no data" and never zero.
    var unitsByDay: [Int64: Int64] = [:]
    for event in smoked {
        unitsByDay[event.epochDay] = saturatingAdd(unitsByDay[event.epochDay] ?? 0, event.units ?? 0)
    }

    let last7Days = ((today - 6) ... today).map { DayUnits(epochDay: $0, units: unitsByDay[$0]) }
    let weekDays = Set(last7Days.map(\.epochDay))
    let setupDay = context.day(of: context.plan.createdAtMs)

    return ReduceSnapshot(
        plan: context.plan,
        todayEpochDay: today,
        todayUnits: unitsByDay[today] ?? 0,
        todayHasEntry: unitsByDay[today] != nil,
        // A REDUCE plan always has a limit (contract §6, `SwitchMode` requires it); falling back to
        // the baseline keeps a malformed row from crashing.
        dailyLimit: context.plan.dailyLimit ?? context.baseline,
        last7Days: last7Days,
        weekReductionUnits: reductionUnits(unitsByDay, days: { weekDays.contains($0) }, in: context),
        weekSavedMinor: reductionMoney(unitsByDay, days: { weekDays.contains($0) }, in: context),
        savedSinceSetupMinor: reductionMoney(unitsByDay, days: { $0 >= setupDay }, in: context),
        cravingsBeatenAllTime: context.input.events.filter { $0.type == .cravingResisted }.count,
        stagesPreview: stagesPreview(),
        goal: goalProgress(context, reduceUnitsByDay: unitsByDay)
    )
}

/// Rule 13: `max(0, baseline - units)` over the logged days that pass `days`.
private func reductionUnits(_ unitsByDay: [Int64: Int64], days include: (Int64) -> Bool, in context: Context) -> Int64 {
    unitsByDay.reduce(0) { total, entry in
        include(entry.key) ? saturatingAdd(total, max(0, context.baseline - entry.value)) : total
    }
}

/// Rule 13: each logged day's reduction at that day's price.
private func reductionMoney(_ unitsByDay: [Int64: Int64], days include: (Int64) -> Bool, in context: Context) -> Int64 {
    unitsByDay.reduce(0) { total, entry in
        guard include(entry.key) else { return total }
        let reduction = max(0, context.baseline - entry.value)
        return saturatingAdd(total, saturatingMultiply(reduction, context.unitCost(on: entry.key)))
    }
}

// MARK: - Goal (rule 14)

private func goalProgress(_ context: Context, reduceUnitsByDay: [Int64: Int64]? = nil) -> GoalProgress? {
    guard let goal = context.input.goal else { return nil }

    let savedToward: Int64
    if let unitsByDay = reduceUnitsByDay {
        // REDUCE: the rule 13 sum over logged days from the goal's own day on.
        let goalDay = context.day(of: goal.createdAtMs)
        savedToward = reductionMoney(unitsByDay, days: { $0 >= goalDay }, in: context)
    } else {
        savedToward = quitGoalSavings(goal, in: context)
    }

    let permille = goal.targetMinor > 0 ? Int(min(1000, scaled(savedToward, 1000, by: goal.targetMinor))) : 0
    return GoalProgress(
        goal: goal,
        savedTowardMinor: savedToward,
        permille: permille,
        reached: savedToward >= goal.targetMinor || goal.achievedAtMs != nil
    )
}

/// QUIT, contract section 8.2: rule 7 applied to each attempt's own window
/// `[max(goal.createdAt, attempt.start), attempt.end ?? now]`, including its `max(0, ...)`, and the
/// goal total is the sum. An attempt whose slips exceed its accrual contributes 0 and never cancels
/// another attempt's savings; a VAPE slip day is deducted once per attempt. The window's end is
/// inclusive for slips, so a restart slip on the closing instant of the old attempt is deducted
/// from it.
private func quitGoalSavings(_ goal: SavingsGoal, in context: Context) -> Int64 {
    context.input.attempts.reduce(0) { total, attempt in
        let from = max(goal.createdAtMs, attempt.startedAtMs)
        let to = attempt.endedAtMs ?? context.nowMs
        guard to > from else { return total }
        let inWindow = slips(of: attempt, in: context).filter { $0.occurredAtMs >= from && $0.occurredAtMs <= to }
        return saturatingAdd(total, savedMinor(from: from, to: to, slips: inWindow, in: context))
    }
}
