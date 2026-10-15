// No Android twin: Android's `ReminderDeepLink.Smoking` builds a back stack in one go, so it cannot
// stack a second main screen. iOS pushes onto the live More stack, and these rows pin which
// screens a milestone notification adds to it — in particular after the person went Back from the
// timeline a first notification opened.

import Testing

@testable import FeatureSmoking

@Suite("SmokingMilestoneRoute")
struct SmokingMilestoneRouteTests {
    private typealias Memo = SmokingPushedScreens

    @Test("an empty stack gets the main screen, then the timeline for a stage")
    func emptyStack() {
        let route = SmokingMilestoneRoute.make(currentDepth: 0, memo: nil, stageId: "s1")

        #expect(route == SmokingMilestoneRoute(
            pops: 0, pushesMain: true, timelineStageId: "s1", memo: Memo(stageId: "s1", depth: 2)
        ))
    }

    @Test("a milestone with no stage pushes the main screen alone")
    func noStageEmptyStack() {
        let route = SmokingMilestoneRoute.make(currentDepth: 3, memo: nil, stageId: nil)

        #expect(route == SmokingMilestoneRoute(
            pops: 0, pushesMain: true, timelineStageId: nil, memo: Memo(stageId: nil, depth: 4)
        ))
    }

    @Test("the same stage again, with its timeline on top, changes nothing")
    func sameStageIsADuplicate() {
        let memo = Memo(stageId: "s1", depth: 2)
        let route = SmokingMilestoneRoute.make(currentDepth: 2, memo: memo, stageId: "s1")

        #expect(route.isNoOp)
        #expect(route.memo == memo)
    }

    @Test("another stage replaces the highlight instead of stacking a second timeline")
    func anotherStageReplacesTheTimeline() {
        let route = SmokingMilestoneRoute.make(
            currentDepth: 2, memo: Memo(stageId: "s1", depth: 2), stageId: "s2"
        )

        #expect(route == SmokingMilestoneRoute(
            pops: 1, pushesMain: false, timelineStageId: "s2", memo: Memo(stageId: "s2", depth: 2)
        ))
    }

    @Test("a stage over the main screen the More row pushed adds only the timeline")
    func timelineOverTheMoreRow() {
        let route = SmokingMilestoneRoute.make(
            currentDepth: 1, memo: Memo(stageId: nil, depth: 1), stageId: "s1"
        )

        #expect(route == SmokingMilestoneRoute(
            pops: 0, pushesMain: false, timelineStageId: "s1", memo: Memo(stageId: "s1", depth: 2)
        ))
    }

    @Test("a stage after Back from the timeline pushes only the timeline over the main screen")
    func backFromTheTimelineThenAnotherStage() {
        // The first notification left [Main, Timeline(s1)], depth 2; Back left [Main], depth 1.
        let route = SmokingMilestoneRoute.make(
            currentDepth: 1, memo: Memo(stageId: "s1", depth: 2), stageId: "s2"
        )

        #expect(route == SmokingMilestoneRoute(
            pops: 0, pushesMain: false, timelineStageId: "s2", memo: Memo(stageId: "s2", depth: 2)
        ))
    }

    @Test("a milestone with no stage after Back from the timeline is a duplicate of the main screen")
    func backFromTheTimelineThenNoStage() {
        let route = SmokingMilestoneRoute.make(
            currentDepth: 1, memo: Memo(stageId: "s1", depth: 2), stageId: nil
        )

        #expect(route.isNoOp)
        #expect(route.memo == Memo(stageId: nil, depth: 1))
    }

    @Test("a milestone with no stage while a timeline is up goes back to the main screen")
    func noStageOverATimeline() {
        let route = SmokingMilestoneRoute.make(
            currentDepth: 2, memo: Memo(stageId: "s1", depth: 2), stageId: nil
        )

        #expect(route == SmokingMilestoneRoute(
            pops: 1, pushesMain: false, timelineStageId: nil, memo: Memo(stageId: nil, depth: 1)
        ))
    }

    @Test("after Back from the main screen itself the next notification pushes it again")
    func backFromTheMainScreen() {
        // [Main] depth 1 popped to depth 0: the memo no longer describes the stack.
        let route = SmokingMilestoneRoute.make(
            currentDepth: 0, memo: Memo(stageId: nil, depth: 1), stageId: "s1"
        )

        #expect(route == SmokingMilestoneRoute(
            pops: 0, pushesMain: true, timelineStageId: "s1", memo: Memo(stageId: "s1", depth: 2)
        ))
    }

    @Test("a memo whose depth matches nothing on the stack is ignored")
    func staleMemo() {
        let route = SmokingMilestoneRoute.make(
            currentDepth: 5, memo: Memo(stageId: "s1", depth: 2), stageId: "s1"
        )

        #expect(route == SmokingMilestoneRoute(
            pops: 0, pushesMain: true, timelineStageId: "s1", memo: Memo(stageId: "s1", depth: 7)
        ))
    }
}
