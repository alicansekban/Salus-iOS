// Ported from Android
// `core/reminder/src/test/kotlin/.../engine/ReminderWindowSynchronizerTest.kt`. Every Kotlin case
// is here under its own name and with the Kotlin assertions, run against `.androidParity` so both
// platforms exercise the same 48h/30 constants (spec §6.1). The iOS-only cases below the divider
// cover the deltas the Android engine has no need for, and run against the shipping `.ios` config
// where the constant is what is under test.
//
// Exactly ONE ported case asserts something different from Kotlin, and the difference is the
// engine's central iOS delta: `sync is idempotent`. Android schedules nothing on a second pass
// because an AlarmManager alarm carries no content; iOS bakes the content into the request, so
// every pass re-`schedule`s every desired occurrence to keep that content fresh. Idempotence on
// iOS therefore means *by identity* — same ledger rows, same pending identifiers — not "no second
// schedule call". The case says so where it asserts it.
//
// The ledger is the real `ReminderAlarmDao` over `SalusDatabase.inMemory`, not a fake: Kotlin's
// `FakeReminderAlarmDao` re-implements the queries by hand, and re-implementing them a second time
// in Swift would test the re-implementation.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel
import SalusTesting
import Testing

@testable import SalusReminder

@Suite("Reminder window synchronizer")
struct ReminderWindowSynchronizerTests {
    /// `ReminderWindowSynchronizerTest.kt:20` — 2025-08-24T02:26:40Z.
    private static let baseNow = Date(epochMilliseconds: 1_756_000_000_000)

    private let dao: ReminderAlarmDao
    private let gateway = RecordingNotificationGateway()
    private let handler = FakeReminderHandler()
    private let environment = FakeReminderEnvironment()
    private let clock: FixedSalusClock

    init() throws {
        let clock = FixedSalusClock(now: Self.baseNow, timeZone: .gmt)
        self.clock = clock
        dao = try ReminderAlarmDao(database: SalusDatabase.inMemory(clock: clock))
    }

    // MARK: - Ported from Kotlin (48h / 30)

    @Test("materializes only occurrences inside the 48h window")
    func materializesOnlyOccurrencesInsideTheWindow() async throws {
        handler.occurrences = [
            occurrence("med-1", "in-window", Self.baseNow + .hours(2)),
            occurrence("med-1", "past-window", Self.baseNow + .hours(49))
        ]

        await makeSynchronizer(.androidParity).sync()

        let rows = try await ledger()
        #expect(rows.count == 1)
        #expect(rows.first?.occurrenceKey == "in-window")
        #expect(gateway.scheduleCalls.count == 1)
    }

    @Test("caps materialization at 30 occurrences, earliest first")
    func capsMaterializationAtThirtyOccurrences() async throws {
        handler.occurrences = (0 ..< 40).map { index in
            occurrence("med-1", "occ-\(index)", Self.baseNow + .minutes(index + 1))
        }

        await makeSynchronizer(.androidParity).sync()

        let keys = try await ledger().map(\.occurrenceKey)
        #expect(keys.count == 30)
        #expect(gateway.scheduleCalls.count == 30)
        #expect(keys.contains("occ-0"))
        #expect(!keys.contains("occ-30"))
    }

    /// The one ported case whose assertions differ — see the file header. Kotlin counts schedule
    /// calls; iOS counts identities, because re-baking the content is the point of the second pass.
    @Test("sync is idempotent - second run schedules nothing new")
    func syncIsIdempotent() async throws {
        handler.occurrences = [
            occurrence("med-1", "a", Self.baseNow + .hours(1)),
            occurrence("med-2", "b", Self.baseNow + .hours(2))
        ]
        let synchronizer = makeSynchronizer(.androidParity)

        await synchronizer.sync()
        let rowsAfterFirst = try await ledger()
        let pendingAfterFirst = await gateway.pendingRequestCodes()

        await synchronizer.sync()
        let rowsAfterSecond = try await ledger()
        let pendingAfterSecond = await gateway.pendingRequestCodes()

        #expect(rowsAfterFirst.count == 2)
        #expect(rowsAfterSecond == rowsAfterFirst)
        #expect(pendingAfterSecond == pendingAfterFirst)
        #expect(gateway.cancelCalls.isEmpty)
    }

    @Test("stale scheduled alarms in the past are marked MISSED")
    func staleScheduledAlarmsInThePastAreMarkedMissed() async throws {
        // On iOS the state a past-due row lands in is a question about the notification
        // authorization: without it nothing was ever presented, which is Android's MISSED.
        environment.isNotificationsAuthorized = false
        handler.occurrences = [occurrence("med-1", "past", Self.baseNow + .hours(1))]
        let synchronizer = makeSynchronizer(.androidParity)
        await synchronizer.sync()

        // Time passes beyond the trigger without the reminder ever reaching us.
        clock.advanceTo(Self.baseNow + .hours(3))
        handler.occurrences = []
        await synchronizer.sync()

        let rows = try await ledger()
        #expect(rows.count == 1)
        #expect(rows.first?.state == AlarmState.missed.rawValue)
        #expect(gateway.cancelCalls.count == 1)
    }

    @Test("occurrences the handler no longer wants are cancelled")
    func occurrencesTheHandlerNoLongerWantsAreCancelled() async throws {
        handler.occurrences = [occurrence("med-1", "gone", Self.baseNow + .hours(5))]
        let synchronizer = makeSynchronizer(.androidParity)
        await synchronizer.sync()

        handler.occurrences = []
        await synchronizer.sync()

        let rows = try await ledger()
        #expect(rows.count == 1)
        #expect(rows.first?.state == AlarmState.cancelled.rawValue)
        #expect(gateway.cancelCalls.count == 1)
    }

    @Test("changed trigger time reschedules the same occurrence")
    func changedTriggerTimeReschedulesTheSameOccurrence() async throws {
        handler.occurrences = [occurrence("med-1", "moving", Self.baseNow + .hours(5))]
        let synchronizer = makeSynchronizer(.androidParity)
        await synchronizer.sync()
        let rowsAfterFirst = try await ledger()
        let originalRow = try #require(rowsAfterFirst.first)

        // Same occurrence identity resolves to a new wall-clock instant (e.g. timezone change).
        handler.occurrences = [occurrence("med-1", "moving", Self.baseNow + .hours(6))]
        await synchronizer.sync()

        let updatedRow = try #require(try await ledger().first)
        #expect(updatedRow.id == originalRow.id)
        #expect(updatedRow.triggerAtEpochMs == (Self.baseNow + .hours(6)).epochMilliseconds)
        #expect(gateway.cancelCalls == [Int32(truncatingIfNeeded: originalRow.requestCode)])
        #expect(gateway.scheduleCalls.count == 2)
    }

    @Test("cancelled row is resurrected with the same id when wanted again")
    func cancelledRowIsResurrectedWithTheSameId() async throws {
        let wanted = occurrence("med-1", "back", Self.baseNow + .hours(5))
        handler.occurrences = [wanted]
        let synchronizer = makeSynchronizer(.androidParity)
        await synchronizer.sync()
        let originalId = try #require(try await ledger().first).id

        handler.occurrences = []
        await synchronizer.sync()
        let cancelledRow = try #require(try await ledger().first)
        #expect(cancelledRow.state == AlarmState.cancelled.rawValue)

        handler.occurrences = [wanted]
        await synchronizer.sync()

        let row = try #require(try await ledger().first)
        #expect(row.id == originalId)
        #expect(row.state == AlarmState.scheduled.rawValue)
    }

    @Test("DST fall-back - 8am local doses are 25 hours apart in wall-clock time")
    func dstFallBackKeepsLocalTimeSemantics() async throws {
        // DST in America/New_York ends 2025-11-02 02:00 (clocks fall back to 01:00).
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        clock.moveToZone(newYork)
        let nov1Morning = clock.instant(of: LocalDate(year: 2025, month: 11, day: 1), minuteOfDay: 8 * 60)
        let nov2Morning = clock.instant(of: LocalDate(year: 2025, month: 11, day: 2), minuteOfDay: 8 * 60)
        clock.advanceTo(clock.instant(of: LocalDate(year: 2025, month: 11, day: 1), minuteOfDay: 0))

        handler.occurrences = [
            occurrence("med-1", "2025-11-01T08:00", nov1Morning),
            occurrence("med-1", "2025-11-02T08:00", nov2Morning)
        ]
        await makeSynchronizer(.androidParity).sync()

        let triggers = gateway.scheduleCalls.map(\.triggerAt).sorted()
        #expect(triggers.count == 2)
        // Local-time semantics hold: the second dose is 25 real hours after the first.
        #expect(triggers[1].timeIntervalSince(triggers[0]) == TimeInterval.hours(25))
    }

    @Test("finished rows older than retention are purged")
    func finishedRowsOlderThanRetentionArePurged() async throws {
        handler.occurrences = [occurrence("med-1", "old", Self.baseNow + .hours(1))]
        let synchronizer = makeSynchronizer(.androidParity)
        await synchronizer.sync()

        clock.advanceTo(Self.baseNow + ReminderWindowSynchronizer.retention + .hours(100))
        handler.occurrences = []
        await synchronizer.sync() // marks the past-due row first
        await synchronizer.sync() // then the next pass purges it

        let rows = try await ledger()
        #expect(rows.isEmpty)
    }

    // MARK: - iOS-only (7 days / 60)

    /// Both platforms must derive the same identifier forever, or an occurrence scheduled on one
    /// could never be cancelled by the other's ledger. The expectations are `String.hashCode()`
    /// read off a JVM; the derivation is in `ReminderWindowSynchronizer.requestCode`.
    @Test("request codes are the Kotlin string hash of the occurrence identity")
    func requestCodesMatchTheKotlinStringHash() {
        #expect(
            ReminderWindowSynchronizer.requestCode(
                type: "MEDICATION_DOSE",
                entityId: "med-1",
                occurrenceKey: "2026-09-01T08:00"
            ) == -620_957_581
        )
        #expect(
            ReminderWindowSynchronizer.requestCode(
                type: "APPOINTMENT",
                entityId: "apt-1",
                occurrenceKey: "2026-09-01T08:00"
            ) == -800_298_168
        )
        #expect(
            ReminderWindowSynchronizer.requestCode(
                type: "CYCLE_PERIOD",
                entityId: "cycle-1",
                occurrenceKey: "2026-09-01T09:00"
            ) == 981_056_651
        )
    }

    @Test("the two window configurations carry the spec constants")
    func windowConfigurationsCarryTheSpecConstants() {
        #expect(ReminderWindowConfig.ios.window == TimeInterval.days(7))
        #expect(ReminderWindowConfig.ios.maxOccurrences == 60)
        #expect(ReminderWindowConfig.androidParity.window == TimeInterval.hours(48))
        #expect(ReminderWindowConfig.androidParity.maxOccurrences == 30)
    }

    @Test("caps materialization at 60 occurrences on the iOS window")
    func capsMaterializationAtSixtyOccurrences() async throws {
        handler.occurrences = (0 ..< 70).map { index in
            occurrence("med-1", "occ-\(index)", Self.baseNow + .minutes(index + 1))
        }

        await makeSynchronizer(.ios).sync()

        let keys = try await ledger().map(\.occurrenceKey)
        #expect(keys.count == 60)
        #expect(gateway.scheduleCalls.count == 60)
        #expect(keys.contains("occ-0"))
        #expect(!keys.contains("occ-60"))
    }

    /// The reason iOS re-schedules on every pass: nothing of ours runs at fire time, so the text
    /// the user reads was baked at the last sync. A renamed medication has to be fixed by the next
    /// sync, and fixing it must not disturb the identity.
    @Test("re-baked content is refreshed while the identity stays fixed")
    func reBakedContentIsRefreshedWhileIdentityStaysFixed() async throws {
        handler.occurrences = [occurrence("med-1", "a", Self.baseNow + .hours(1))]
        let synchronizer = makeSynchronizer(.ios)
        await synchronizer.sync()
        let rowsAfterFirst = try await ledger()
        let pendingAfterFirst = await gateway.pendingRequestCodes()

        handler.content = ReminderNotificationContent(title: "renamed", text: "20 mg")
        await synchronizer.sync()
        let rowsAfterSecond = try await ledger()
        let pendingAfterSecond = await gateway.pendingRequestCodes()

        #expect(rowsAfterSecond == rowsAfterFirst)
        #expect(pendingAfterSecond == pendingAfterFirst)
        #expect(gateway.scheduleCalls.last?.content.title == "renamed")
        #expect(gateway.cancelCalls.isEmpty)
    }

    @Test("a past-due row is FIRED when notifications are authorized")
    func pastDueRowIsFiredWhenNotificationsAreAuthorized() async throws {
        environment.isNotificationsAuthorized = true
        handler.occurrences = [occurrence("med-1", "past", Self.baseNow + .hours(1))]
        let synchronizer = makeSynchronizer(.ios)
        await synchronizer.sync()

        clock.advanceTo(Self.baseNow + .hours(3))
        handler.occurrences = []
        await synchronizer.sync()

        // The OS presented it; delivered-then-dismissed is indistinguishable and assumed delivered.
        let row = try #require(try await ledger().first)
        #expect(row.state == AlarmState.fired.rawValue)
        #expect(gateway.cancelCalls.count == 1)
    }

    @Test("a row the OS no longer holds pending is re-scheduled")
    func rowMissingFromPendingIsRescheduled() async throws {
        handler.occurrences = [occurrence("med-1", "a", Self.baseNow + .hours(1))]
        let synchronizer = makeSynchronizer(.ios)
        await synchronizer.sync()
        let code = try #require(gateway.scheduleCalls.first).requestCode

        // The notification centre dropped the request without a cancellation.
        gateway.evictFromPending(code)
        await synchronizer.sync()
        let pending = await gateway.pendingRequestCodes()

        #expect(pending.contains(code))
        #expect(gateway.scheduleCalls.count == 2)
        #expect(gateway.cancelCalls.isEmpty)
    }

    @Test("nil content cancels the occurrence instead of scheduling it")
    func nilContentCancelsTheOccurrence() async throws {
        handler.occurrences = [occurrence("med-1", "a", Self.baseNow + .hours(1))]
        let synchronizer = makeSynchronizer(.ios)
        await synchronizer.sync()
        let code = try #require(gateway.scheduleCalls.first).requestCode

        // The handler stops recognizing the occurrence — the entity behind it is gone.
        handler.content = nil
        await synchronizer.sync()
        let row = try #require(try await ledger().first)
        let pending = await gateway.pendingRequestCodes()

        #expect(row.state == AlarmState.cancelled.rawValue)
        #expect(gateway.cancelCalls == [code])
        #expect(pending.isEmpty)
        #expect(gateway.scheduleCalls.count == 1)
    }

    /// The window is a rolling one, and on iOS nothing refills it while the app is closed. After a
    /// cold period the very next sync has to materialize the whole horizon again from where it now
    /// stands, not resume where it stopped.
    @Test("a cold period of five days is refilled by one sync")
    func coldPeriodIsRefilledByOneSync() async throws {
        handler.occurrences = (0 ..< 20).map { index in
            occurrence("med-1", "occ-\(index)", Self.baseNow + .days(index))
        }
        let synchronizer = makeSynchronizer(.ios)
        await synchronizer.sync()
        let scheduledWhileWarm = try await dao.getScheduled()
        #expect(scheduledWhileWarm.count == 7)

        clock.advanceTo(Self.baseNow + .days(5))
        await synchronizer.sync()

        let scheduled = try await dao.getScheduled()
        #expect(scheduled.map(\.occurrenceKey) == (5 ... 11).map { "occ-\($0)" })
        #expect(scheduled.first?.triggerAtEpochMs == (Self.baseNow + .days(5)).epochMilliseconds)
    }

    // MARK: - Fixture

    private func makeSynchronizer(_ config: ReminderWindowConfig) -> ReminderWindowSynchronizer {
        ReminderWindowSynchronizer(
            dao: dao,
            gateway: gateway,
            handlerRegistry: ReminderHandlerRegistry(all: [handler]),
            environment: environment,
            clock: clock,
            idGenerator: SequentialIdGenerator(),
            config: config
        )
    }

    private func occurrence(_ entityId: String, _ key: String, _ triggerAt: Date) -> ReminderOccurrence {
        ReminderOccurrence(entityId: entityId, occurrenceKey: key, triggerAt: triggerAt)
    }

    /// The whole ledger, soonest first. `ReminderAlarmDao` has no "select everything" query and
    /// Room does not declare one either, so the suite reads it back through the queries that exist,
    /// over the two entity ids these cases write.
    private func ledger() async throws -> [ReminderAlarmRecord] {
        var rows: [ReminderAlarmRecord] = []
        for entityId in ["med-1", "med-2"] {
            rows += try await dao.getByEntity(type: ReminderType.medicationDose.rawValue, entityId: entityId)
        }
        return rows.sorted { $0.triggerAtEpochMs < $1.triggerAtEpochMs }
    }
}

/// Kotlin's cases are written in `2.hours` / `49.hours`; this is that spelling in the unit
/// `Foundation` measures an offset from a `Date` in.
extension TimeInterval {
    fileprivate static func minutes(_ count: Int) -> TimeInterval {
        TimeInterval(count) * 60
    }

    fileprivate static func hours(_ count: Int) -> TimeInterval {
        TimeInterval(count) * 60 * 60
    }

    fileprivate static func days(_ count: Int) -> TimeInterval {
        TimeInterval(count) * 24 * 60 * 60
    }
}
