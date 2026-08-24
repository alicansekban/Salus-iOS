// Ported from Android
// `core/reminder/src/test/kotlin/.../engine/ReminderWindowSynchronizerTest.kt`. Every Kotlin case
// is here under its own name and with the Kotlin assertions, run against `.androidParity` so both
// platforms exercise the same 48h/30 constants (spec §6.1). The deltas the Android engine has no
// need for are a separate suite, `ReminderWindowSynchronizerIOSTests`.
//
// Exactly ONE case here asserts something different from Kotlin, and the difference is the
// engine's central iOS delta: `sync is idempotent`. Android schedules nothing on a second pass
// because an AlarmManager alarm carries no content; iOS bakes the content into the request, so
// every pass re-`schedule`s every desired occurrence to keep that content fresh. Idempotence on
// iOS therefore means *by identity* — same ledger rows, same pending identifiers — not "no second
// schedule call". The case says so where it asserts it.
//
// The ledger is the real `ReminderAlarmDao` over `SalusDatabase.inMemory`, not a fake: Kotlin's
// `FakeReminderAlarmDao` re-implements the queries by hand, and re-implementing them a second time
// in Swift would test the re-implementation. `SynchronizerFixture` in `Fakes.swift` holds it and
// everything else both suites inject.

import Foundation
import SalusCommon
import SalusModel
import Testing

@testable import SalusReminder

@Suite("Reminder window synchronizer (Android parity)")
struct ReminderWindowSynchronizerTests {
    /// `ReminderWindowSynchronizerTest.kt:20` — 2025-08-24T02:26:40Z.
    private static let baseNow = SynchronizerFixture.baseNow

    private let fixture: SynchronizerFixture

    init() throws {
        fixture = try SynchronizerFixture()
    }

    @Test("materializes only occurrences inside the 48h window")
    func materializesOnlyOccurrencesInsideTheWindow() async throws {
        fixture.handler.occurrences = [
            fixture.occurrence("med-1", "in-window", Self.baseNow + .hours(2)),
            fixture.occurrence("med-1", "past-window", Self.baseNow + .hours(49))
        ]

        await fixture.makeSynchronizer(.androidParity).sync()

        let rows = try await fixture.ledger()
        #expect(rows.count == 1)
        #expect(rows.first?.occurrenceKey == "in-window")
        #expect(fixture.gateway.scheduleCalls.count == 1)
    }

    @Test("caps materialization at 30 occurrences, earliest first")
    func capsMaterializationAtThirtyOccurrences() async throws {
        fixture.handler.occurrences = (0 ..< 40).map { index in
            fixture.occurrence("med-1", "occ-\(index)", Self.baseNow + .minutes(index + 1))
        }

        await fixture.makeSynchronizer(.androidParity).sync()

        let keys = try await fixture.ledger().map(\.occurrenceKey)
        #expect(keys.count == 30)
        #expect(fixture.gateway.scheduleCalls.count == 30)
        #expect(keys.contains("occ-0"))
        #expect(!keys.contains("occ-30"))
    }

    /// The one ported case whose assertions differ — see the file header. Kotlin counts schedule
    /// calls; iOS counts identities, because re-baking the content is the point of the second pass.
    @Test("sync is idempotent - second run schedules nothing new")
    func syncIsIdempotent() async throws {
        fixture.handler.occurrences = [
            fixture.occurrence("med-1", "a", Self.baseNow + .hours(1)),
            fixture.occurrence("med-2", "b", Self.baseNow + .hours(2))
        ]
        let synchronizer = fixture.makeSynchronizer(.androidParity)

        await synchronizer.sync()
        let rowsAfterFirst = try await fixture.ledger()
        let pendingAfterFirst = await fixture.gateway.pendingRequestCodes()

        await synchronizer.sync()
        let rowsAfterSecond = try await fixture.ledger()
        let pendingAfterSecond = await fixture.gateway.pendingRequestCodes()

        #expect(rowsAfterFirst.count == 2)
        #expect(rowsAfterSecond == rowsAfterFirst)
        #expect(pendingAfterSecond == pendingAfterFirst)
        #expect(fixture.gateway.cancelCalls.isEmpty)
    }

    @Test("stale scheduled alarms in the past are marked MISSED")
    func staleScheduledAlarmsInThePastAreMarkedMissed() async throws {
        // On iOS the state a past-due row lands in is a question about the notification
        // authorization: without it nothing was ever presented, which is Android's MISSED.
        fixture.environment.isNotificationsAuthorized = false
        fixture.handler.occurrences = [fixture.occurrence("med-1", "past", Self.baseNow + .hours(1))]
        let synchronizer = fixture.makeSynchronizer(.androidParity)
        await synchronizer.sync()

        // Time passes beyond the trigger without the reminder ever reaching us.
        fixture.clock.advanceTo(Self.baseNow + .hours(3))
        fixture.handler.occurrences = []
        await synchronizer.sync()

        let rows = try await fixture.ledger()
        #expect(rows.count == 1)
        #expect(rows.first?.state == AlarmState.missed.rawValue)
        #expect(fixture.gateway.cancelCalls.count == 1)
    }

    @Test("occurrences the handler no longer wants are cancelled")
    func occurrencesTheHandlerNoLongerWantsAreCancelled() async throws {
        fixture.handler.occurrences = [fixture.occurrence("med-1", "gone", Self.baseNow + .hours(5))]
        let synchronizer = fixture.makeSynchronizer(.androidParity)
        await synchronizer.sync()

        fixture.handler.occurrences = []
        await synchronizer.sync()

        let rows = try await fixture.ledger()
        #expect(rows.count == 1)
        #expect(rows.first?.state == AlarmState.cancelled.rawValue)
        #expect(fixture.gateway.cancelCalls.count == 1)
    }

    @Test("changed trigger time reschedules the same occurrence")
    func changedTriggerTimeReschedulesTheSameOccurrence() async throws {
        fixture.handler.occurrences = [fixture.occurrence("med-1", "moving", Self.baseNow + .hours(5))]
        let synchronizer = fixture.makeSynchronizer(.androidParity)
        await synchronizer.sync()
        let rowsAfterFirst = try await fixture.ledger()
        let originalRow = try #require(rowsAfterFirst.first)

        // Same occurrence identity resolves to a new wall-clock instant (e.g. timezone change).
        fixture.handler.occurrences = [fixture.occurrence("med-1", "moving", Self.baseNow + .hours(6))]
        await synchronizer.sync()

        let updatedRow = try #require(try await fixture.ledger().first)
        #expect(updatedRow.id == originalRow.id)
        #expect(updatedRow.triggerAtEpochMs == (Self.baseNow + .hours(6)).epochMilliseconds)
        #expect(fixture.gateway.cancelCalls == [Int32(truncatingIfNeeded: originalRow.requestCode)])
        #expect(fixture.gateway.scheduleCalls.count == 2)
    }

    @Test("cancelled row is resurrected with the same id when wanted again")
    func cancelledRowIsResurrectedWithTheSameId() async throws {
        let wanted = fixture.occurrence("med-1", "back", Self.baseNow + .hours(5))
        fixture.handler.occurrences = [wanted]
        let synchronizer = fixture.makeSynchronizer(.androidParity)
        await synchronizer.sync()
        let originalId = try #require(try await fixture.ledger().first).id

        fixture.handler.occurrences = []
        await synchronizer.sync()
        let cancelledRow = try #require(try await fixture.ledger().first)
        #expect(cancelledRow.state == AlarmState.cancelled.rawValue)

        fixture.handler.occurrences = [wanted]
        await synchronizer.sync()

        let row = try #require(try await fixture.ledger().first)
        #expect(row.id == originalId)
        #expect(row.state == AlarmState.scheduled.rawValue)
    }

    @Test("DST fall-back - 8am local doses are 25 hours apart in wall-clock time")
    func dstFallBackKeepsLocalTimeSemantics() async throws {
        // DST in America/New_York ends 2025-11-02 02:00 (clocks fall back to 01:00).
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        fixture.clock.moveToZone(newYork)
        let nov1Morning = fixture.clock.instant(of: LocalDate(year: 2025, month: 11, day: 1), minuteOfDay: 8 * 60)
        let nov2Morning = fixture.clock.instant(of: LocalDate(year: 2025, month: 11, day: 2), minuteOfDay: 8 * 60)
        fixture.clock.advanceTo(fixture.clock.instant(of: LocalDate(year: 2025, month: 11, day: 1), minuteOfDay: 0))

        fixture.handler.occurrences = [
            fixture.occurrence("med-1", "2025-11-01T08:00", nov1Morning),
            fixture.occurrence("med-1", "2025-11-02T08:00", nov2Morning)
        ]
        await fixture.makeSynchronizer(.androidParity).sync()

        let triggers = fixture.gateway.scheduleCalls.map(\.triggerAt).sorted()
        #expect(triggers.count == 2)
        // Local-time semantics hold: the second dose is 25 real hours after the first.
        #expect(triggers[1].timeIntervalSince(triggers[0]) == TimeInterval.hours(25))
    }

    @Test("finished rows older than retention are purged")
    func finishedRowsOlderThanRetentionArePurged() async throws {
        fixture.handler.occurrences = [fixture.occurrence("med-1", "old", Self.baseNow + .hours(1))]
        let synchronizer = fixture.makeSynchronizer(.androidParity)
        await synchronizer.sync()

        fixture.clock.advanceTo(Self.baseNow + ReminderWindowSynchronizer.retention + .hours(100))
        fixture.handler.occurrences = []
        await synchronizer.sync() // marks the past-due row first
        await synchronizer.sync() // then the next pass purges it

        let rows = try await fixture.ledger()
        #expect(rows.isEmpty)
    }
}
