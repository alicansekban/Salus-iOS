// Contract section 8.13's truth check, on its own: of the kinds a key still produces, a Stage that
// is not yet DONE and a Days(n) whose instant has not been reached are dropped, so nothing is
// announced before it is true. Ported from the fire-time cases of Android's
// `SmokingReminderHandlerTest.kt`; the handler suite covers the same rule through
// `notificationContent` (evaluated as of the notification's own instant on iOS, see the handler).

import SalusSmoking
import Testing

@testable import FeatureSmoking

@Suite("Smoking milestone truth check")
struct SmokingMilestoneTruthTests {
    private typealias Fix = SmokingReminderFixtures

    private func quitSnapshot(at local: String) -> SmokingSnapshot {
        SmokingStatsCalculator.snapshot(Fix.quitInput(), nowMs: Fix.ms(local), zone: Fix.zone)
    }

    @Test("a stage that is not yet done is dropped, and kept once it is")
    func stageNotYetDoneIsDropped() {
        let input = Fix.quitInput()

        #expect(!SmokingReminderHandler.stillTrue(
            .stage("h_20m"),
            input: input,
            snapshot: quitSnapshot(at: "2026-03-10T09:19")
        ))
        #expect(SmokingReminderHandler.stillTrue(
            .stage("h_20m"),
            input: input,
            snapshot: quitSnapshot(at: "2026-03-10T09:20")
        ))
    }

    @Test("a day count whose instant has not been reached is dropped, and kept once it is")
    func dayNotYetReachedIsDropped() {
        let input = Fix.quitInput()

        #expect(!SmokingReminderHandler.stillTrue(
            .days(1),
            input: input,
            snapshot: quitSnapshot(at: "2026-03-11T08:59")
        ))
        #expect(SmokingReminderHandler.stillTrue(
            .days(1),
            input: input,
            snapshot: quitSnapshot(at: "2026-03-11T09:00")
        ))
    }

    @Test("a stage or a day count is untrue without a quit attempt")
    func stageAndDaysNeedAQuitSnapshot() {
        let reduce = SmokingStatsCalculator.snapshot(
            Fix.reduceInput(evening: true),
            nowMs: Fix.ms("2026-03-10T12:00"),
            zone: Fix.zone
        )

        #expect(!SmokingReminderHandler.stillTrue(
            .stage("h_20m"),
            input: Fix.reduceInput(evening: true),
            snapshot: reduce
        ))
        #expect(!SmokingReminderHandler.stillTrue(.days(1), input: Fix.reduceInput(evening: true), snapshot: reduce))
    }
}
