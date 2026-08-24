// The iOS half of the `ReminderWindowSynchronizer` suite: the deltas Android's engine has no need
// for, run against the shipping `.ios` config (7 days / 60) where the constant is what is under
// test. The ported Kotlin cases are the sibling `ReminderWindowSynchronizerTests`, whose header
// explains the split and the one adapted assertion; both share `SynchronizerFixture`.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel
import Testing

@testable import SalusReminder

@Suite("Reminder window synchronizer (iOS deltas)")
struct ReminderWindowSynchronizerIOSTests {
    /// `ReminderWindowSynchronizerTest.kt:20` — 2025-08-24T02:26:40Z.
    private static let baseNow = SynchronizerFixture.baseNow

    private let fixture: SynchronizerFixture

    init() throws {
        fixture = try SynchronizerFixture()
    }

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
        fixture.handler.occurrences = (0 ..< 70).map { index in
            fixture.occurrence("med-1", "occ-\(index)", Self.baseNow + .minutes(index + 1))
        }

        await fixture.makeSynchronizer(.ios).sync()

        let keys = try await fixture.ledger().map(\.occurrenceKey)
        #expect(keys.count == 60)
        #expect(fixture.gateway.scheduleCalls.count == 60)
        #expect(keys.contains("occ-0"))
        #expect(!keys.contains("occ-60"))
    }

    /// The reason iOS re-schedules on every pass: nothing of ours runs at fire time, so the text
    /// the user reads was baked at the last sync. A renamed medication has to be fixed by the next
    /// sync, and fixing it must not disturb the identity.
    @Test("re-baked content is refreshed while the identity stays fixed")
    func reBakedContentIsRefreshedWhileIdentityStaysFixed() async throws {
        fixture.handler.occurrences = [fixture.occurrence("med-1", "a", Self.baseNow + .hours(1))]
        let synchronizer = fixture.makeSynchronizer(.ios)
        await synchronizer.sync()
        let rowsAfterFirst = try await fixture.ledger()
        let pendingAfterFirst = await fixture.gateway.pendingRequestCodes()

        fixture.handler.content = ReminderNotificationContent(title: "renamed", text: "20 mg")
        await synchronizer.sync()
        let rowsAfterSecond = try await fixture.ledger()
        let pendingAfterSecond = await fixture.gateway.pendingRequestCodes()

        #expect(rowsAfterSecond == rowsAfterFirst)
        #expect(pendingAfterSecond == pendingAfterFirst)
        #expect(fixture.gateway.scheduleCalls.last?.content.title == "renamed")
        #expect(fixture.gateway.cancelCalls.isEmpty)
    }

    @Test("a past-due row is FIRED when notifications are authorized")
    func pastDueRowIsFiredWhenNotificationsAreAuthorized() async throws {
        fixture.environment.isNotificationsAuthorized = true
        fixture.handler.occurrences = [fixture.occurrence("med-1", "past", Self.baseNow + .hours(1))]
        let synchronizer = fixture.makeSynchronizer(.ios)
        await synchronizer.sync()

        fixture.clock.advanceTo(Self.baseNow + .hours(3))
        fixture.handler.occurrences = []
        await synchronizer.sync()

        // The OS presented it; delivered-then-dismissed is indistinguishable and assumed delivered.
        let row = try #require(try await fixture.ledger().first)
        #expect(row.state == AlarmState.fired.rawValue)
        #expect(fixture.gateway.cancelCalls.count == 1)
    }

    @Test("a row the OS no longer holds pending is re-scheduled")
    func rowMissingFromPendingIsRescheduled() async throws {
        fixture.handler.occurrences = [fixture.occurrence("med-1", "a", Self.baseNow + .hours(1))]
        let synchronizer = fixture.makeSynchronizer(.ios)
        await synchronizer.sync()
        let code = try #require(fixture.gateway.scheduleCalls.first).requestCode

        // The notification centre dropped the request without a cancellation.
        fixture.gateway.evictFromPending(code)
        await synchronizer.sync()
        let pending = await fixture.gateway.pendingRequestCodes()

        #expect(pending.contains(code))
        #expect(fixture.gateway.scheduleCalls.count == 2)
        #expect(fixture.gateway.cancelCalls.isEmpty)
    }

    @Test("nil content cancels the occurrence instead of scheduling it")
    func nilContentCancelsTheOccurrence() async throws {
        fixture.handler.occurrences = [fixture.occurrence("med-1", "a", Self.baseNow + .hours(1))]
        let synchronizer = fixture.makeSynchronizer(.ios)
        await synchronizer.sync()
        let code = try #require(fixture.gateway.scheduleCalls.first).requestCode

        // The handler stops recognizing the occurrence — the entity behind it is gone.
        fixture.handler.content = nil
        await synchronizer.sync()
        let row = try #require(try await fixture.ledger().first)
        let pending = await fixture.gateway.pendingRequestCodes()

        #expect(row.state == AlarmState.cancelled.rawValue)
        #expect(fixture.gateway.cancelCalls == [code])
        #expect(pending.isEmpty)
        #expect(fixture.gateway.scheduleCalls.count == 1)
    }

    /// The ledger says nothing about this occurrence any more, but the notification centre is
    /// still holding its request — the state a row reaches by firing, or by any write that takes it
    /// out of `getScheduled` while the OS keeps what was already handed to it. Reconciling against
    /// the ledger alone would leave that request to present text the feature has disowned.
    @Test("a pending request with no live row is cancelled when the content goes nil")
    func pendingRequestWithoutLiveRowIsCancelled() async throws {
        fixture.handler.occurrences = [fixture.occurrence("med-1", "a", Self.baseNow + .hours(1))]
        let synchronizer = fixture.makeSynchronizer(.ios)
        await synchronizer.sync()
        let code = try #require(fixture.gateway.scheduleCalls.first).requestCode
        let row = try #require(try await fixture.ledger().first)

        // The row leaves the scheduler's working set while the request stays pending.
        try await fixture.dao.updateState(id: row.id, newState: AlarmState.fired.rawValue)
        fixture.handler.content = nil
        await synchronizer.sync()

        let pending = await fixture.gateway.pendingRequestCodes()
        #expect(fixture.gateway.cancelCalls == [code])
        #expect(pending.isEmpty)
        // Nothing was re-scheduled for it, and the row was left exactly as it was found.
        #expect(fixture.gateway.scheduleCalls.count == 1)
        #expect(try await fixture.ledger().first?.state == AlarmState.fired.rawValue)
    }

    /// Kotlin lets one bad occurrence abort the pass because WorkManager retries the worker. iOS
    /// has no retry twin, so the failure has to stay local to the occurrence that caused it.
    @Test("an occurrence that cannot be materialized does not starve the rest of the pass")
    func failingOccurrenceDoesNotStarveThePass() async throws {
        // A finished row is squatting on the request code the first desired occurrence derives, so
        // its insert hits the unique request_code index rather than the primary key.
        let squattedCode = ReminderWindowSynchronizer.requestCode(
            type: ReminderType.medicationDose.rawValue,
            entityId: "med-1",
            occurrenceKey: "a"
        )
        try await fixture.dao.upsert(
            ReminderAlarmRecord(
                id: "squatter",
                type: ReminderType.medicationDose.rawValue,
                entityId: "med-2",
                occurrenceKey: "squatter",
                triggerAtEpochMs: (Self.baseNow + .hours(9)).epochMilliseconds,
                requestCode: Int(squattedCode),
                state: AlarmState.cancelled.rawValue
            )
        )

        fixture.handler.occurrences = [
            fixture.occurrence("med-1", "a", Self.baseNow + .hours(1)),
            fixture.occurrence("med-2", "b", Self.baseNow + .hours(2))
        ]
        await fixture.makeSynchronizer(.ios).sync()

        let keys = try await fixture.ledger().map(\.occurrenceKey)
        #expect(!keys.contains("a"))
        #expect(keys.contains("b"))
        // The later occurrence still reached the notification centre.
        #expect(fixture.gateway.scheduleCalls.map(\.ref.occurrenceKey) == ["b"])
    }

    /// The window is a rolling one, and on iOS nothing refills it while the app is closed. After a
    /// cold period the very next sync has to materialize the whole horizon again from where it now
    /// stands, not resume where it stopped.
    @Test("a cold period of five days is refilled by one sync")
    func coldPeriodIsRefilledByOneSync() async throws {
        fixture.handler.occurrences = (0 ..< 20).map { index in
            fixture.occurrence("med-1", "occ-\(index)", Self.baseNow + .days(index))
        }
        let synchronizer = fixture.makeSynchronizer(.ios)
        await synchronizer.sync()
        let scheduledWhileWarm = try await fixture.dao.getScheduled()
        #expect(scheduledWhileWarm.count == 7)

        fixture.clock.advanceTo(Self.baseNow + .days(5))
        await synchronizer.sync()

        let scheduled = try await fixture.dao.getScheduled()
        #expect(scheduled.map(\.occurrenceKey) == (5 ... 11).map { "occ-\($0)" })
        #expect(scheduled.first?.triggerAtEpochMs == (Self.baseNow + .days(5)).epochMilliseconds)
    }
}
