// Twin of `feature/smoking/.../reminder/SmokingReminderHandler.kt` on branch
// `feature/m17-smoking-cessation`, with the contract's section 4 (amended) and section 8.13
// (delivery anchoring) as the authority.
//
// Delivery goes through the existing reminder engine as `ReminderType.smoking` (iOS delta D3), so
// nothing here schedules anything: the engine's window (7 days / 60 occurrences) is what bounds
// the pending notifications, and `SmokingReminderResync` asks it to refill after every write.
//
// iOS difference from Android, forced by the platform and not by the contract: nothing of ours runs
// when a notification fires, so the engine calls `notificationContent` at SYNC time and bakes the
// text into the pending request (`ReminderWindowSynchronizer.materialize`), where Android's receiver
// calls it when the alarm fires. Contract section 8.13's "a Stage not yet DONE and a Days(n) not yet
// reached are dropped" is therefore evaluated as of the notification's own instant,
// `max(now, planned trigger)`, and not as of `now`: at sync time every future milestone is "not yet
// reached", so the literal reading would withdraw every milestone and schedule nothing. The guard
// the rule exists for - a slip or an edited quit date makes an already-scheduled text untrue - is
// the resync every write requests: it re-plans the key, moves its trigger to the new instant and
// re-bakes it, or cancels it when the key is gone.

import Foundation
import SalusCommon
import SalusModel
import SalusReminder
import SalusSmoking

/// What the reminder engine stores in a SMOKING occurrence's `entityId`, and what a tap on the
/// notification reads back: `smoking:<stageId>` highlights that stage on the timeline, a bare
/// `smoking` has nothing to highlight.
public enum SmokingReminderEntity {
    public static let entityId = "smoking"

    private static let stagePrefix = "\(entityId):"

    /// The most advanced stage among `kinds`; a merged day lands on the newest one it announces.
    public static func entityId(of kinds: [MilestoneKind]) -> String {
        let lastStage = kinds.reversed().lazy.compactMap { kind -> String? in
            if case let .stage(stageId) = kind {
                stageId
            } else {
                nil
            }
        }.first
        return lastStage.map { stagePrefix + $0 } ?? entityId
    }

    public static func stageId(of entityId: String) -> String? {
        guard entityId.hasPrefix(stagePrefix) else { return nil }
        let stageId = String(entityId.dropFirst(stagePrefix.count))
        return stageId.isEmpty ? nil : stageId
    }
}

/// Feature handler for ``ReminderType/smoking``: milestone notifications planned by
/// `MilestoneScheduler` (contract section 4). The occurrence key is the planner's own key
/// (`q:<attemptId>:<date>`, `q:<attemptId>:<date>:early`, `r:<planId>:<date>`).
public struct SmokingReminderHandler: ReminderHandler {
    public let type: ReminderType = .smoking

    private static let msPerDay: Int64 = 86_400_000
    private static let quietStartMinute = 22 * 60

    private let repository: any SmokingRepository
    private let clock: any SalusClock
    private let strings: any SmokingNotificationStrings

    public init(
        repository: any SmokingRepository,
        clock: any SalusClock,
        strings: any SmokingNotificationStrings
    ) {
        self.repository = repository
        self.clock = clock
        self.strings = strings
    }

    /// Contract section 8.13: every local day is planned as of its own anchor, never as of the
    /// sync's `now`. Planned as of `now`, a first-48 h day with three instants would be split again
    /// after its early notification fired (the engine re-syncs after every fired alarm), minting a
    /// third notification. Anchored, the plan for a day is the same however often the engine syncs,
    /// and it is the very plan ``notificationContent(for:)`` re-derives, so the two agree by
    /// construction.
    public func occurrencesBetween(from: Date, until: Date) async throws -> [ReminderOccurrence] {
        let fromMs = from.epochMilliseconds
        let untilMs = until.epochMilliseconds
        guard untilMs > fromMs, let input = await currentInput() else { return [] }
        let zone = clock.timeZone()
        let firstDay = localDate(of: fromMs, in: zone)
        let lastDay = localDate(of: untilMs - 1, in: zone)
        guard firstDay <= lastDay else { return [] }

        var planned: [PlannedNotification] = []
        for epochDay in firstDay.epochDay ... lastDay.epochDay {
            let day = LocalDate(epochDay: epochDay)
            let forDay = MilestoneScheduler.plan(input, nowMs: anchor(of: input, day: day, zone: zone), zone: zone)
            planned += forDay.filter { notification in
                PlannedKey.parse(notification.key)?.date == day
                    && notification.triggerAtMs >= fromMs && notification.triggerAtMs < untilMs
            }
        }
        return planned
            .sorted { $0.triggerAtMs < $1.triggerAtMs }
            .map { notification in
                ReminderOccurrence(
                    entityId: SmokingReminderEntity.entityId(of: notification.kinds),
                    occurrenceKey: notification.key,
                    triggerAt: Date(epochMilliseconds: notification.triggerAtMs)
                )
            }
    }

    /// Re-derives what the key announces from the data as it is now, and returns nil when it no
    /// longer holds: tracking was reset, the plan switched mode, notifications were turned off, the
    /// attempt is another one, or a slip or an edited quit date moved the milestone past this
    /// moment. A notification must never state something that is not true yet.
    public func notificationContent(for ref: ReminderRef) async throws -> ReminderNotificationContent? {
        guard let key = PlannedKey.parse(ref.occurrenceKey),
              let input = await currentInput(),
              let plan = input.plan
        else { return nil }
        let zone = clock.timeZone()
        let nowMs = clock.nowEpochMilliseconds()

        let anchored = MilestoneScheduler.plan(input, nowMs: anchor(of: input, day: key.date, zone: zone), zone: zone)
        guard let planned = anchored.first(where: { $0.key == key.raw }) else { return nil }
        // As of the notification's own instant, or now when that has passed - see the file header.
        let snapshot = SmokingStatsCalculator.snapshot(input, nowMs: max(nowMs, planned.triggerAtMs), zone: zone)
        let kinds = planned.kinds.filter { Self.stillTrue($0, input: input, snapshot: snapshot) }
        guard let copy = SmokingNotificationText.compose(
            kinds: kinds,
            currencyCode: plan.currencyCode,
            strings: strings
        ) else { return nil }
        return ReminderNotificationContent(title: copy.title, text: copy.text, presentation: .notification)
    }

    /// `max(local 22:00 of the evening before the day, active attempt start)` minus 1 ms: just
    /// before the quiet window that shifts into `day` begins, so every kind that can fire on `day`
    /// lies strictly after it. The attempt start keeps the projections (units, money) counting from
    /// the quit date instead of from before it. Local 22:00 and not "start of day minus 2 h": the
    /// two differ in zones whose daylight-saving change happens at midnight, and only 22:00 matches
    /// the scheduler's quiet hours (contract 8.13).
    private func anchor(of input: SmokingInput, day: LocalDate, zone: TimeZone) -> Int64 {
        let beforeQuietStart = LocalDateTime(date: day.minusDays(1), minuteOfDay: Self.quietStartMinute)
            .instant(in: zone).epochMilliseconds - 1
        let attemptStart = input.attempts.filter { $0.endedAtMs == nil }.map(\.startedAtMs).max()
        return max(beforeQuietStart, attemptStart ?? .min)
    }

    /// Whether a kind of the notification is true at the instant `snapshot` was taken for. A stage and a day count are
    /// fixed by the data, so they are checked against it: a slip that restarted the stage clock or
    /// a quit date moved later makes them untrue. An amount or a unit count is a projection that
    /// every write re-plans, which moves or cancels its notification, so it is left to that resync.
    /// An evening reminder is skipped when the day already has an entry.
    static func stillTrue(_ kind: MilestoneKind, input: SmokingInput, snapshot: SmokingSnapshot) -> Bool {
        switch kind {
        case let .stage(stageId):
            guard case let .quit(quit) = snapshot else { return false }
            return quit.stages.first { $0.stageId == stageId }?.state == .done

        case let .days(days):
            guard case let .quit(quit) = snapshot else { return false }
            return quit.attemptElapsedMs >= days * Self.msPerDay

        case .money, .units:
            return true

        case let .evening(epochDay):
            // "Has an entry" is the daily log: a smoked row, or the "none today" marker. A resisted
            // craving is not a log of the day.
            return !input.events.contains { $0.type == .smoked && $0.epochDay == epochDay }
        }
    }

    /// Kotlin's `repository.observeInput().first()`: take one value and stop collecting. A stream
    /// that ends empty describes no plan, which is the "nothing to remind about" case.
    private func currentInput() async -> SmokingInput? {
        for await input in repository.observeInput() {
            return input
        }
        return nil
    }

    private func localDate(of epochMs: Int64, in zone: TimeZone) -> LocalDate {
        Date(epochMilliseconds: epochMs).wallClock(in: zone).date
    }

    /// `q:<attemptId>:<yyyy-MM-dd>[:early]` or `r:<planId>:<yyyy-MM-dd>`.
    private struct PlannedKey {
        let raw: String
        let date: LocalDate

        static func parse(_ raw: String) -> PlannedKey? {
            let parts = raw.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            let shapeOk = switch parts.first {
            case "q": parts.count == 3 || (parts.count == 4 && parts[3] == "early")
            case "r": parts.count == 3
            default: false
            }
            guard shapeOk, let date = isoDate(parts[2]) else { return nil }
            return PlannedKey(raw: raw, date: date)
        }

        /// A strict `yyyy-MM-dd`: `LocalDate` normalises an impossible day (2026-02-30 becomes
        /// 2026-03-02), which would let a mangled key re-plan some other day.
        private static func isoDate(_ text: String) -> LocalDate? {
            let fields = text.split(separator: "-", omittingEmptySubsequences: false)
            guard fields.count == 3,
                  fields[0].count == 4, fields[1].count == 2, fields[2].count == 2,
                  let year = Int(fields[0]), let month = Int(fields[1]), let day = Int(fields[2]),
                  (1 ... 12).contains(month), day >= 1
            else { return nil }
            let date = LocalDate(year: year, month: month, day: day)
            return date.day == day && date.month == month ? date : nil
        }
    }
}

/// Re-plans the milestone notifications after every committed smoking write: setup, a slip, a
/// restart, a mode switch, a price, quit-date or switch edit, a reset. `requestSync()` is a unique
/// coalesced job, so calling it on the writing task costs an enqueue, not a pass.
public struct SmokingReminderResync: SmokingChangeListener {
    private let scheduler: any ReminderScheduler

    public init(scheduler: any ReminderScheduler) {
        self.scheduler = scheduler
    }

    public func smokingDataChanged() {
        scheduler.requestSync()
    }
}
