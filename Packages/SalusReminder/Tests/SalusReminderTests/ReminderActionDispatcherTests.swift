// The action pipeline `ReminderActionDispatcher` owns, ported from Kotlin's
// `HandleReminderActionUseCase`: look the occurrence up by request code, hand it to the feature
// that owns it, and refill the window afterwards — whatever the handler did or failed to do.
//
// The ledger is the real `ReminderAlarmDao` over `SalusDatabase.inMemory`, for the reason
// `ReminderWindowSynchronizerTests` gives: a fake dao would be a second implementation of the very
// query whose result this type is built on.
//
// The recording doubles (`DelegateEventLog`, `RecordingReminderHandler`,
// `RecordingWindowSynchronizer`, `HandlerFailure`) are `ReminderNotificationDelegateTests`', shared
// rather than re-declared: the delegate and the dispatcher assert the same ORDER, so they should
// fail against the same log type.

import Foundation
import SalusDatabase
import SalusModel
import SalusTesting
import Testing

@testable import SalusReminder

/// The ledger plus the recording collaborators, in one value.
struct DispatcherFixture {
    /// The same instant the synchronizer suites are written around; the ledger row's trigger time
    /// is never read by the dispatcher, so any fixed value does.
    static let triggerAt = Date(timeIntervalSince1970: 1_756_000_000)

    let log = DelegateEventLog()
    let dao: ReminderAlarmDao

    init() throws {
        dao = try ReminderAlarmDao(database: SalusDatabase.inMemory(clock: FixedSalusClock(now: Self.triggerAt)))
    }

    /// Writes one `SCHEDULED` ledger row and answers the ref it stands for.
    @discardableResult
    func ledgerRow(
        requestCode: Int,
        type: ReminderType = .medicationDose,
        entityId: String = "med-1",
        occurrenceKey: String = "2026-09-01T08:00"
    ) async throws -> ReminderRef {
        try await dao.upsert(
            ReminderAlarmRecord(
                id: "alarm-\(requestCode)",
                type: type.rawValue,
                entityId: entityId,
                occurrenceKey: occurrenceKey,
                triggerAtEpochMs: Int64(Self.triggerAt.timeIntervalSince1970 * 1000),
                requestCode: requestCode,
                state: AlarmState.scheduled.rawValue
            )
        )
        return ReminderRef(type: type, entityId: entityId, occurrenceKey: occurrenceKey)
    }

    /// The full dispatcher — the one the alarm surface gets, with a ledger to look codes up in.
    func dispatcher(handlers: [any ReminderHandler]) -> ReminderActionDispatcher {
        ReminderActionDispatcher(
            alarmDao: dao,
            registry: ReminderHandlerRegistry(all: handlers),
            synchronizer: RecordingWindowSynchronizer(log: log)
        )
    }

    /// The ledger-less dispatcher the notification path gets, which is handed the occurrence
    /// identity in `userInfo` and never sees a request code.
    func refOnlyDispatcher(handlers: [any ReminderHandler]) -> ReminderActionDispatcher {
        ReminderActionDispatcher(
            alarmDao: nil,
            registry: ReminderHandlerRegistry(all: handlers),
            synchronizer: RecordingWindowSynchronizer(log: log)
        )
    }

    func handler(_ type: ReminderType = .medicationDose, failing: (any Error)? = nil) -> RecordingReminderHandler {
        RecordingReminderHandler(type: type, log: log, failure: failing)
    }
}

@Suite("ReminderActionDispatcher")
struct ReminderActionDispatcherTests {
    /// `HandleReminderActionUseCase.kt:19-23`: the request code is all the alarm surface hands back,
    /// so the occurrence identity is read out of the ledger row and only then handed to the feature
    /// — and the refill follows, because a snooze materializes its new occurrence inside `onAction`.
    @Test("a known request code reaches the owning handler with the ledger row's ref, then syncs")
    func knownRequestCodeDispatchesThenSyncs() async throws {
        let fixture = try DispatcherFixture()
        let ref = try await fixture.ledgerRow(requestCode: 41)

        await fixture.dispatcher(handlers: [fixture.handler()]).perform(requestCode: 41, actionId: "taken")

        #expect(fixture.log.recorded == [.action(ref, "taken"), .sync])
    }

    /// A code the ledger does not carry — an alarm from a build whose window has since been rebuilt,
    /// or one the engine already reconciled away. Kotlin returns early and skips the sync; iOS does
    /// not, for the reason the delegate gives: the refill is a property of the event having happened,
    /// not of the occurrence still being known, and skipping it leaves the window one slot short.
    @Test("an unknown request code dispatches to nobody but still refills the window")
    func unknownRequestCodeOnlySyncs() async throws {
        let fixture = try DispatcherFixture()

        await fixture.dispatcher(handlers: [fixture.handler()]).perform(requestCode: 99, actionId: "taken")

        #expect(fixture.log.recorded == [.sync])
    }

    /// A row whose type no feature registered — the medication handler arrives with M5, the cycle one
    /// with M6, and the engine reconciles without either. Kotlin's `handler?.onAction(...)`.
    @Test("a row whose type no feature owns still refills the window")
    func rowWithoutHandlerOnlySyncs() async throws {
        let fixture = try DispatcherFixture()
        try await fixture.ledgerRow(requestCode: 42, type: .cyclePeriod, entityId: "cycle-1")

        await fixture.dispatcher(handlers: [fixture.handler(.medicationDose)]).perform(
            requestCode: 42,
            actionId: "taken"
        )

        #expect(fixture.log.recorded == [.sync])
    }

    /// A handler that throws is a bug in a feature, not a reason to lose the refill: there is nobody
    /// to report to — an `AppIntent` that rethrows would show the user a system failure alert for a
    /// dose that was recorded — so it is absorbed and logged, and the window is still refilled.
    @Test("a handler that throws does not stop the window from being refilled")
    func throwingHandlerStillSyncs() async throws {
        let fixture = try DispatcherFixture()
        let ref = try await fixture.ledgerRow(requestCode: 43)

        await fixture.dispatcher(handlers: [fixture.handler(failing: HandlerFailure())]).perform(
            requestCode: 43,
            actionId: "snooze"
        )

        #expect(fixture.log.recorded == [.action(ref, "snooze"), .sync])
    }

    /// The alarm's stop button is the engine's ``ReminderActionIds/dismiss``, and it reaches the
    /// handler under that name rather than a second spelling of the same idea. Handlers deliberately
    /// do not implement it — the dose stays unresolved — but the dispatch and the refill still happen.
    @Test("the engine's dismiss id reaches the handler unchanged")
    func dismissReachesTheHandlerAsIs() async throws {
        let fixture = try DispatcherFixture()
        let ref = try await fixture.ledgerRow(requestCode: 44)

        await fixture.dispatcher(handlers: [fixture.handler()]).perform(
            requestCode: 44,
            actionId: ReminderActionIds.dismiss
        )

        #expect(fixture.log.recorded == [.action(ref, ReminderActionIds.dismiss), .sync])
    }

    // MARK: - The ref entry point

    /// What the notification delegate calls: the occurrence identity travelled in `userInfo`, so
    /// there is no ledger lookup to do and the pipeline starts at the handler.
    @Test("a ref dispatches to the owning handler and then refills the window")
    func refDispatchesThenSyncs() async throws {
        let fixture = try DispatcherFixture()
        let ref = ReminderRef(type: .appointment, entityId: "appt-4", occurrenceKey: "2026-10-02T09:30")

        await fixture.refOnlyDispatcher(handlers: [fixture.handler(.appointment)]).perform(
            ref: ref,
            actionId: "snooze"
        )

        #expect(fixture.log.recorded == [.action(ref, "snooze"), .sync])
    }

    /// A ledger-less dispatcher has nowhere to resolve a request code, so it resolves nothing — and
    /// still syncs, exactly as it does for a code the ledger does not carry.
    @Test("a dispatcher built without a ledger answers a request code with the refill alone")
    func requestCodeWithoutLedgerOnlySyncs() async throws {
        let fixture = try DispatcherFixture()
        try await fixture.ledgerRow(requestCode: 45)

        await fixture.refOnlyDispatcher(handlers: [fixture.handler()]).perform(requestCode: 45, actionId: "taken")

        #expect(fixture.log.recorded == [.sync])
    }
}
