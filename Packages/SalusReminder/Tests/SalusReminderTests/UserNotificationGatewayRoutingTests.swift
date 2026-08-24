// Where an occurrence goes, and what it costs: the `.alarm` fork of spec's 2026-08-23 AlarmKit
// note, cancellation across both backends, and the 64-pending-request budget §6.1's window math is
// written against.
//
// The AlarmKit half is deliberately thin: only the ROUTING decision is unit-tested, through the
// `AlarmKitScheduling` seam. AlarmKit itself is iOS 26+ and cannot run under `swift test` (the host
// is macOS, where the framework does not exist), so the real payload is validated on device in
// iOS-M5 — the plan's M3a. The request shape is the sibling `UserNotificationGatewayTests`.

import Foundation
import SalusModel
import Testing
import UserNotifications

@testable import SalusReminder

@Suite("UserNotificationGateway routing")
struct UserNotificationGatewayRoutingTests {
    private let fixture = GatewayFixture()

    // MARK: - Presentation routing

    /// The ordinary path: nothing urgent, the system sound, no interruption-level escalation.
    @Test("a notification presentation posts a plain request with the default sound")
    func notificationPresentationIsPlain() async throws {
        try await fixture.gateway().schedule(
            requestCode: 20,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(presentation: .notification),
            ref: fixture.ref(.appointment, "appt-1")
        )

        let content = try #require(fixture.center.pending.first?.content)
        #expect(content.sound == UNNotificationSound.default)
        #expect(content.interruptionLevel == .active)
    }

    /// Spec's AlarmKit note, case 2 — no alarm backend. Silent mode still silences it; that
    /// degradation is accepted, and Critical Alerts are deliberately not used.
    @Test("an alarm presentation without AlarmKit falls back to time-sensitive plus the alarm sound")
    func alarmPresentationFallsBackToTimeSensitive() async throws {
        try await fixture.gateway().schedule(
            requestCode: 21,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(presentation: .alarm),
            ref: fixture.ref()
        )

        let content = try #require(fixture.center.pending.first?.content)
        #expect(content.interruptionLevel == .timeSensitive)
        #expect(content.sound == UNNotificationSound(named: UNNotificationSoundName(ReminderAlarmSound.fileName)))
        #expect(content.sound != UNNotificationSound.default)
    }

    /// The custom sound has to name the file that is actually in the bundle. iOS ignores a sound it
    /// cannot find — or one longer than 30 s — and plays the default instead, silently.
    @Test("the alarm sound names the bundled file")
    func alarmSoundNamesTheBundledFile() {
        #expect(ReminderAlarmSound.fileName == "salus_alarm.caf")
    }

    /// Spec's AlarmKit note, case 1. A real system alarm, and it does NOT consume one of the 64
    /// pending-notification slots — which is why nothing reaches the centre here.
    @Test("an alarm presentation routes to AlarmKit when the alarm backend is reachable")
    func alarmPresentationRoutesToAlarmKit() async throws {
        let alarms = FakeAlarmKitScheduler()
        let ref = fixture.ref()
        let content = fixture.content(title: "Metformin", text: "1 tablet", presentation: .alarm)

        try await fixture.gateway(alarmScheduler: alarms).schedule(
            requestCode: 22,
            triggerAt: GatewayFixture.triggerAt,
            content: content,
            ref: ref
        )

        #expect(fixture.center.pending.isEmpty)
        #expect(alarms.scheduleCalls == [
            ScheduledAlarm(requestCode: 22, triggerAt: GatewayFixture.triggerAt, content: content, ref: ref)
        ])
    }

    /// The presentation is handler-owned: an ordinary reminder never takes over the screen just
    /// because the device could.
    @Test("a notification presentation never routes to AlarmKit")
    func notificationPresentationNeverRoutesToAlarmKit() async throws {
        let alarms = FakeAlarmKitScheduler()

        try await fixture.gateway(alarmScheduler: alarms).schedule(
            requestCode: 23,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(presentation: .notification),
            ref: fixture.ref(.cyclePeriod, "cycle-1")
        )

        #expect(alarms.scheduleCalls.isEmpty)
        #expect(fixture.center.pending.count == 1)
    }

    // MARK: - Cancellation and reconciliation

    /// Cancellation is given a request code, never a backend: the ledger does not record which one
    /// scheduled the occurrence, and it does not need to — the code addresses the request in the
    /// centre and derives the AlarmKit id, so both are told and whichever holds it drops it.
    @Test("cancel removes the request from both backends")
    func cancelRemovesFromBothBackends() async throws {
        let alarms = FakeAlarmKitScheduler()
        let gateway = fixture.gateway(alarmScheduler: alarms)

        try await gateway.schedule(
            requestCode: 30,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(),
            ref: fixture.ref(.appointment, "appt-1")
        )
        try await gateway.schedule(
            requestCode: 31,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(presentation: .alarm),
            ref: fixture.ref()
        )

        await gateway.cancel(requestCodes: [30, 31])

        #expect(fixture.center.pending.isEmpty)
        // The tail, because scheduling 30 as a notification already told the alarm backend to drop
        // whatever it held under that code — the two replace cases below.
        #expect(alarms.cancelCalls.suffix(2) == [30, 31])
        #expect(await gateway.pendingRequestCodes().isEmpty)
    }

    /// "Adds — or replaces — the request for `requestCode`" is the gateway's contract, and with two
    /// backends behind it that has to mean replacing in both: a handler that changed an
    /// occurrence's presentation would otherwise leave the old backend holding it, and the user
    /// would be told twice.
    @Test("switching an occurrence to an alarm drops the notification it had")
    func switchingToAnAlarmDropsTheNotification() async throws {
        let gateway = fixture.gateway(alarmScheduler: FakeAlarmKitScheduler())

        try await gateway.schedule(
            requestCode: 32,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(presentation: .notification),
            ref: fixture.ref()
        )
        try await gateway.schedule(
            requestCode: 32,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(presentation: .alarm),
            ref: fixture.ref()
        )

        #expect(fixture.center.pending.isEmpty)
        #expect(await gateway.pendingRequestCodes() == [32])
    }

    /// The same rule read backwards.
    @Test("switching an occurrence to a notification drops the alarm it had")
    func switchingToANotificationDropsTheAlarm() async throws {
        let alarms = FakeAlarmKitScheduler()
        let gateway = fixture.gateway(alarmScheduler: alarms)

        try await gateway.schedule(
            requestCode: 33,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(presentation: .alarm),
            ref: fixture.ref()
        )
        try await gateway.schedule(
            requestCode: 33,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(presentation: .notification),
            ref: fixture.ref()
        )

        #expect(await alarms.scheduledRequestCodes().isEmpty)
        #expect(await gateway.pendingRequestCodes() == [33])
    }

    /// Cancelling something neither backend holds is a no-op, not an error — the synchronizer
    /// cancels in batches built from the ledger, which can be ahead of reality.
    @Test("cancelling an unknown request code is a no-op")
    func cancellingAnUnknownCodeIsANoOp() async {
        let gateway = fixture.gateway()

        await gateway.cancel(requestCodes: [999])

        #expect(await gateway.pendingRequestCodes().isEmpty)
    }

    /// What the synchronizer reconciles against: reality across BOTH backends, so an occurrence
    /// scheduled as an alarm is not mistaken for one the OS dropped.
    @Test("pendingRequestCodes unions the notification centre and AlarmKit")
    func pendingRequestCodesUnionsBothBackends() async throws {
        let gateway = fixture.gateway(alarmScheduler: FakeAlarmKitScheduler())

        try await gateway.schedule(
            requestCode: 40,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(),
            ref: fixture.ref(.appointment, "appt-1")
        )
        try await gateway.schedule(
            requestCode: -41,
            triggerAt: GatewayFixture.triggerAt,
            content: fixture.content(presentation: .alarm),
            ref: fixture.ref()
        )

        #expect(await gateway.pendingRequestCodes() == [40, -41])
    }

    /// A request the centre holds under an identifier that is not a request code — something
    /// scheduled outside the engine — is ignored rather than derailing the reconciliation.
    @Test("a foreign pending identifier is ignored")
    func foreignPendingIdentifiersAreIgnored() async throws {
        let gateway = fixture.gateway()
        try await fixture.center.add(
            UNNotificationRequest(
                identifier: "not-a-request-code",
                content: UNMutableNotificationContent(),
                trigger: nil
            )
        )

        #expect(await gateway.pendingRequestCodes().isEmpty)
    }

    // MARK: - Budget tripwire

    /// iOS keeps at most 64 pending requests per app and drops the rest SILENTLY. §6.1 caps the
    /// window at 60 so this is unreachable; the tripwire exists to say so out loud if the cap ever
    /// stops holding, because the failure mode it guards against makes no noise of its own.
    @Test("scheduling past the pending budget reports the overflow")
    func schedulingPastTheBudgetReportsTheOverflow() async throws {
        let reported = OverflowRecorder()
        let gateway = fixture.gateway(onPendingBudgetExceeded: { reported.record($0) })

        for code in 0 ..< 70 {
            try await gateway.schedule(
                requestCode: Int32(code),
                triggerAt: GatewayFixture.triggerAt,
                content: fixture.content(),
                ref: fixture.ref(.appointment, "appt-\(code)")
            )
        }

        #expect(fixture.center.pending.count == 70)
        // First reported the moment the 65th landed, and on every request after it.
        #expect(reported.counts == Array(65 ... 70))
    }

    /// The shipping window stays quiet, which is the whole point of the §6.1 numbers.
    @Test("scheduling the whole shipping window stays under the budget")
    func theShippingWindowStaysUnderTheBudget() async throws {
        let reported = OverflowRecorder()
        let gateway = fixture.gateway(onPendingBudgetExceeded: { reported.record($0) })

        for code in 0 ..< ReminderWindowConfig.ios.maxOccurrences {
            try await gateway.schedule(
                requestCode: Int32(code),
                triggerAt: GatewayFixture.triggerAt,
                content: fixture.content(),
                ref: fixture.ref(.appointment, "appt-\(code)")
            )
        }

        #expect(reported.counts.isEmpty)
    }

    /// The relief the spec's AlarmKit note promises: doses scheduled through AlarmKit are not
    /// pending notifications at all, so they cannot exhaust the budget.
    @Test("AlarmKit schedules do not consume the pending budget")
    func alarmKitSchedulesDoNotConsumeTheBudget() async throws {
        let reported = OverflowRecorder()
        let gateway = fixture.gateway(
            alarmScheduler: FakeAlarmKitScheduler(),
            onPendingBudgetExceeded: { reported.record($0) }
        )

        for code in 0 ..< 70 {
            try await gateway.schedule(
                requestCode: Int32(code),
                triggerAt: GatewayFixture.triggerAt,
                content: fixture.content(presentation: .alarm),
                ref: fixture.ref(.medicationDose, "med-\(code)")
            )
        }

        #expect(fixture.center.pending.isEmpty)
        #expect(reported.counts.isEmpty)
    }

    /// The budget is the number iOS actually enforces, not a copy of the §6.1 cap — the two are
    /// different numbers on purpose, and the four slots between them are left for whatever is
    /// scheduled outside the engine.
    @Test("the budget is the OS limit, four above the window cap")
    func theBudgetIsTheOSLimit() {
        #expect(UserNotificationGateway.systemPendingBudget == 64)
        #expect(ReminderWindowConfig.ios.maxOccurrences == 60)
    }

    // MARK: - AlarmKit identity

    /// Cancellation is handed a request code long after the process that scheduled the alarm has
    /// died, so AlarmKit's `UUID` has to be recomputable from it rather than remembered — the same
    /// bargain the request code itself strikes with the occurrence identity.
    @Test(
        "an alarm id round-trips to its request code",
        arguments: [Int32(0), 1, -1, 42, .max, .min, -1_234_567_890]
    )
    func alarmIdsRoundTrip(code: Int32) {
        let alarmId = ReminderAlarmIdentity.alarmId(for: code)

        #expect(ReminderAlarmIdentity.requestCode(of: alarmId) == code)
        #expect(ReminderAlarmIdentity.alarmId(for: code) == alarmId)
    }

    /// Distinct occurrences must not collide, or cancelling one would silence another.
    @Test("distinct request codes mint distinct alarm ids")
    func distinctCodesMintDistinctIds() {
        let ids = Set((-50 ... 50).map { ReminderAlarmIdentity.alarmId(for: Int32($0)) })

        #expect(ids.count == 101)
    }

    /// An alarm somebody else scheduled is not ours to report as pending, let alone to cancel.
    @Test("a foreign alarm id carries no request code")
    func foreignAlarmIdsCarryNoRequestCode() {
        #expect(ReminderAlarmIdentity.requestCode(of: UUID()) == nil)
    }
}
