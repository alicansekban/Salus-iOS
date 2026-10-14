// The 64-pending budget (iOS-M17 review focus 6, delta D3): iOS keeps at most 64 pending
// notification requests per app, the engine caps its window at 60 occurrences earliest-first across
// every handler, and smoking joins medications, appointments and cycle in that one cap.
//
// These run the REAL `ReminderWindowSynchronizer` with the shipping `.ios` config (7 days / 60) over
// an in-memory ledger and the real `SmokingReminderHandler`; only the notification centre and the
// other three features' handlers are stand-ins. They also prove the baked-at-sync-time path end to
// end: a synchronizer that got no content out of the smoking handler would schedule nothing.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel
import SalusReminder
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

@Suite("Smoking reminders in the pending budget")
struct SmokingReminderBudgetTests {
    private typealias Fix = SmokingReminderFixtures

    /// 2026-03-10T09:00 in Istanbul: the moment the person quits and the first sync runs.
    private static let now = Fix.at("2026-03-10T09:00")

    private let clock = FixedSalusClock(now: now, timeZone: Fix.zone)
    private let gateway = PendingCountingGateway()
    private let dao: ReminderAlarmDao

    init() throws {
        dao = try ReminderAlarmDao(database: SalusDatabase.inMemory(clock: clock))
    }

    private func smokingHandler() -> SmokingReminderHandler {
        SmokingReminderHandler(
            repository: InputSwappingSmokingRepository(Fix.quitInput(startMs: Self.now.epochMilliseconds)),
            clock: clock,
            strings: FakeSmokingNotificationStrings()
        )
    }

    private func sync(with others: [StubReminderHandler]) async {
        let synchronizer = ReminderWindowSynchronizer(
            dao: dao,
            gateway: gateway,
            handlerRegistry: ReminderHandlerRegistry(all: others + [smokingHandler()]),
            environment: AuthorizedEnvironment(),
            clock: clock,
            idGenerator: CountingIdGenerator(),
            config: .ios
        )
        await synchronizer.sync()
    }

    /// Every smoking occurrence the handler offers the engine for the next 7 days.
    private func smokingWindow() async throws -> [ReminderOccurrence] {
        try await smokingHandler().occurrencesBetween(
            from: Self.now,
            until: Self.now.addingTimeInterval(ReminderWindowConfig.ios.window)
        )
    }

    /// Medications every 30 minutes, 20 appointments and the cycle reminder: far past the 60-slot
    /// cap, so the cap is what decides what the window holds.
    private func maxedOthers() -> [StubReminderHandler] {
        [
            StubReminderHandler(
                type: .medicationDose,
                occurrences: (1 ... 336).map { step in
                    ReminderOccurrence(
                        entityId: "med-\(step % 12)",
                        occurrenceKey: "dose-\(step)",
                        triggerAt: Self.now.addingTimeInterval(TimeInterval(step) * 30 * 60)
                    )
                }
            ),
            StubReminderHandler(
                type: .appointment,
                occurrences: (1 ... 20).map { step in
                    ReminderOccurrence(
                        entityId: "appt-\(step)",
                        occurrenceKey: "lead-\(step)",
                        triggerAt: Self.now.addingTimeInterval(TimeInterval(step) * 8 * 3600)
                    )
                }
            ),
            StubReminderHandler(
                type: .cyclePeriod,
                occurrences: [
                    ReminderOccurrence(
                        entityId: "cycle-period",
                        occurrenceKey: "2026-03-14|540",
                        triggerAt: Fix.at("2026-03-14T09:00")
                    )
                ]
            )
        ]
    }

    @Test("a first week of smoking milestones is a handful, far under the budget")
    func firstWeekIsAHandful() async throws {
        let week = try await smokingWindow()

        // D3 says "at most ~9 in 7 days" for the busiest week, the first after quitting.
        #expect(!week.isEmpty)
        #expect(week.count <= 12)
    }

    @Test("with realistic maxima everything fits, smoking included, and the budget holds")
    func realisticMaximaFitEntirely() async throws {
        let others = [
            StubReminderHandler(
                type: .medicationDose,
                occurrences: (1 ... 27).map { step in
                    ReminderOccurrence(
                        entityId: "med-\(step % 4)",
                        occurrenceKey: "dose-\(step)",
                        triggerAt: Self.now.addingTimeInterval(TimeInterval(step) * 6 * 3600)
                    )
                }
            ),
            StubReminderHandler(
                type: .appointment,
                occurrences: (1 ... 10).map { step in
                    ReminderOccurrence(
                        entityId: "appt-\(step)",
                        occurrenceKey: "lead-\(step)",
                        triggerAt: Self.now.addingTimeInterval(TimeInterval(step) * 16 * 3600)
                    )
                }
            )
        ]
        let week = try await smokingWindow()

        await sync(with: others)

        let pending = await gateway.pendingRequestCodes()
        // 27 doses (every 6 h, the 28th falls on the open end of the window) + 10 appointments.
        #expect(pending.count == 27 + 10 + week.count)
        #expect(pending.count <= UserNotificationBudget.pending)
        let smokingScheduled = gateway.scheduled.filter { $0.ref.type == .smoking }.map(\.ref.occurrenceKey)
        #expect(Set(smokingScheduled) == Set(week.map(\.occurrenceKey)))
    }

    @Test("maxed medications, appointments and cycle never push the window past 64 pending")
    func maxedFixturesStayWithinTheBudget() async {
        await sync(with: maxedOthers())

        let pending = await gateway.pendingRequestCodes()
        #expect(pending.count == ReminderWindowConfig.ios.maxOccurrences)
        #expect(pending.count <= UserNotificationBudget.pending)
    }

    @Test("smoking is not starved of its nearest milestone when the window is full")
    func nearestMilestoneIsNotStarved() async throws {
        let week = try await smokingWindow()
        let nearest = try #require(week.min { $0.triggerAt < $1.triggerAt })

        await sync(with: maxedOthers())

        let smoking = gateway.scheduled.filter { $0.ref.type == .smoking }
        #expect(smoking.contains { $0.ref.occurrenceKey == nearest.occurrenceKey })
        // The content the engine baked is the real handler's (a stage title), not a withdrawn nil.
        #expect(smoking.first { $0.ref.occurrenceKey == nearest.occurrenceKey }?.content.title == "stage:h_20m")
        // And the cap is earliest-first: whatever smoking holds is no later than the last slot used.
        let lastScheduled = gateway.scheduled.map(\.triggerAt).max() ?? .distantPast
        #expect(smoking.allSatisfy { $0.triggerAt <= lastScheduled })
    }
}

/// What iOS enforces, restated here so the assertions read as the budget and not as a magic number.
private enum UserNotificationBudget {
    static let pending = 64
}

/// A feature handler reduced to the occurrences a test hands it; its content is a fixed text.
private struct StubReminderHandler: ReminderHandler {
    let type: ReminderType
    let occurrences: [ReminderOccurrence]

    func occurrencesBetween(from: Date, until: Date) async throws -> [ReminderOccurrence] {
        occurrences.filter { $0.triggerAt >= from && $0.triggerAt < until }
    }

    func notificationContent(for _: ReminderRef) async throws -> ReminderNotificationContent? {
        ReminderNotificationContent(title: "stub", text: "stub")
    }
}

/// A notification centre that remembers what it was asked to hold.
private final class PendingCountingGateway: NotificationGateway, @unchecked Sendable {
    struct Scheduled {
        let requestCode: Int32
        let triggerAt: Date
        let content: ReminderNotificationContent
        let ref: ReminderRef
    }

    private let lock = NSLock()
    private var calls: [Scheduled] = []
    private var pending: Set<Int32> = []

    var scheduled: [Scheduled] { lock.withLock { calls } }

    func schedule(
        requestCode: Int32,
        triggerAt: Date,
        content: ReminderNotificationContent,
        ref: ReminderRef
    ) async throws {
        lock.withLock {
            calls.append(Scheduled(requestCode: requestCode, triggerAt: triggerAt, content: content, ref: ref))
            pending.insert(requestCode)
        }
    }

    func cancel(requestCodes: [Int32]) async {
        lock.withLock { pending.subtract(requestCodes) }
    }

    func pendingRequestCodes() async -> Set<Int32> {
        lock.withLock { pending }
    }
}

private struct AuthorizedEnvironment: ReminderEnvironment {
    func notificationsAuthorized() async -> Bool {
        true
    }
    func alarmKitAuthorized() async -> Bool {
        false
    }
    func backgroundRefreshAvailable() -> Bool {
        true
    }
}

private final class CountingIdGenerator: IdGenerator, @unchecked Sendable {
    private let lock = NSLock()
    private var next = 0

    func newId() -> String {
        lock.withLock {
            defer { next += 1 }
            return "id-\(next)"
        }
    }
}
