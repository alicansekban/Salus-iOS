// How the merged kinds of one planned notification read as a title and a body, what a tap reads back
// from the occurrence's entity id, and the resync listener. Ported from Android's
// `SmokingNotificationTextTest.kt` (the three classes it holds).

import Foundation
import SalusModel
import SalusReminder
import SalusSmoking
import Testing

@testable import FeatureSmoking

@Suite("Smoking notification text")
struct SmokingNotificationTextTests {
    private func compose(_ kinds: MilestoneKind...) -> SmokingNotificationCopy? {
        SmokingNotificationText.compose(kinds: kinds, currencyCode: "TRY", strings: FakeSmokingNotificationStrings())
    }

    /// Stage ids the strings do not know, everything else as the fake.
    private struct UnknownStageStrings: SmokingNotificationStrings {
        private let base = FakeSmokingNotificationStrings()
        func stageReached(stageId _: String) -> String? {
            nil
        }
        func daysReached(_ days: Int64) -> String {
            base.daysReached(days)
        }
        func unitsSkipped(_ units: Int64) -> String {
            base.unitsSkipped(units)
        }
        func moneySaved(minor: Int64, currencyCode: String) -> String {
            base.moneySaved(minor: minor, currencyCode: currencyCode)
        }
        func stageHint() -> String {
            base.stageHint()
        }
        func cheer() -> String {
            base.cheer()
        }
        func eveningTitle() -> String {
            base.eveningTitle()
        }
        func eveningText() -> String {
            base.eveningText()
        }
    }

    @Test("a day milestone is the good news and a cheer follows")
    func dayMilestoneIsGoodNewsThenCheer() {
        let text = compose(.days(7))

        #expect(text?.title == "days:7")
        #expect(text?.text == "cheer")
    }

    @Test("a money milestone names the amount in the plan currency")
    func moneyNamesTheAmount() {
        #expect(compose(.money(100_000))?.title == "money:100000:TRY")
    }

    @Test("a units milestone names the count")
    func unitsNamesTheCount() {
        #expect(compose(.units(500))?.title == "units:500")
    }

    @Test("a stage points at the timeline")
    func stagePointsAtTheTimeline() {
        let text = compose(.stage("h_12h"))

        #expect(text?.title == "stage:h_12h")
        #expect(text?.text == "stage-hint")
    }

    @Test("merged milestones lead with the first and list the rest")
    func mergedLeadWithTheFirst() {
        let text = compose(.days(7), .money(50000), .units(100))

        #expect(text?.title == "days:7")
        #expect(text?.text == "money:50000:TRY · units:100")
    }

    @Test("the evening reminder has its own wording")
    func eveningHasItsOwnWording() {
        let text = compose(.evening(20000))

        #expect(text?.title == "evening-title")
        #expect(text?.text == "evening-text")
    }

    @Test("a stage the strings do not know is left out rather than invented")
    func unknownStageIsLeftOut() {
        let text = SmokingNotificationText.compose(
            kinds: [.stage("h_unknown"), .days(3)],
            currencyCode: "TRY",
            strings: UnknownStageStrings()
        )

        #expect(text?.title == "days:3")
        #expect(text?.text == "cheer")
    }

    @Test("nothing to announce composes nothing")
    func nothingComposesNothing() {
        #expect(compose() == nil)
        #expect(
            SmokingNotificationText.compose(
                kinds: [.stage("h_unknown")], currencyCode: "TRY", strings: UnknownStageStrings()
            ) == nil
        )
    }
}

@Suite("Smoking reminder entity id")
struct SmokingReminderEntityTests {
    @Test("a stage travels in the entity id and comes back")
    func stageTravels() {
        let entityId = SmokingReminderEntity.entityId(of: [.days(3), .stage("h_72h")])

        #expect(entityId == "smoking:h_72h")
        #expect(SmokingReminderEntity.stageId(of: entityId) == "h_72h")
    }

    @Test("a merged day points at its most advanced stage")
    func mergedDayPointsAtTheNewestStage() {
        let entityId = SmokingReminderEntity.entityId(of: [.stage("h_12h"), .stage("h_48h"), .money(50000)])

        #expect(entityId == "smoking:h_48h")
    }

    @Test("a day without a stage has nothing to highlight")
    func noStageNothingToHighlight() {
        let entityId = SmokingReminderEntity.entityId(of: [.days(7), .units(100)])

        #expect(entityId == "smoking")
        #expect(SmokingReminderEntity.stageId(of: entityId) == nil)
        #expect(SmokingReminderEntity.stageId(of: "smoking:") == nil)
    }
}

@Suite("Smoking reminder resync")
struct SmokingReminderResyncTests {
    private final class CountingScheduler: ReminderScheduler, @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        var syncs: Int { lock.withLock { count } }
        func requestSync() {
            lock.withLock { count += 1 }
        }
    }

    @Test("a committed smoking write requests a reminder sync")
    func writeRequestsASync() {
        let scheduler = CountingScheduler()

        SmokingReminderResync(scheduler: scheduler).smokingDataChanged()

        #expect(scheduler.syncs == 1)
    }
}
