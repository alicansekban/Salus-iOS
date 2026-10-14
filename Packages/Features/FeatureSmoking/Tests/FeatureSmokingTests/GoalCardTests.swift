// Ported from `feature/smoking/src/test/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// GoalCardTest.kt`: which goal card the main screen draws, and the "about n days" estimate on the
// in-progress one.

import SalusSmoking
import Testing

@testable import FeatureSmoking

@Suite("Goal card state", .timeLimit(.minutes(1)))
struct GoalCardTests {
    private let day: Int64 = 24 * 60 * 60 * 1000

    private let plan = SmokingPlan(
        id: "plan",
        mode: .quit,
        productType: .cigarette,
        baselineUnitsPerDay: 20,
        dailyLimit: nil,
        currencyCode: "TRY",
        reason: nil,
        notificationsEnabled: true,
        eveningReminderEnabled: false,
        createdAtMs: 0,
        tzId: "Europe/Istanbul"
    )

    private func goal(target: Int64 = 800_000, achievedAtMs: Int64? = nil) -> SavingsGoal {
        SavingsGoal(
            id: "goal-1",
            title: "Yeni bisiklet",
            targetMinor: target,
            createdAtMs: 0,
            achievedAtMs: achievedAtMs
        )
    }

    private func progress(saved: Int64, target: Int64 = 800_000, achievedAtMs: Int64? = nil) -> GoalProgress {
        GoalProgress(
            goal: goal(target: target, achievedAtMs: achievedAtMs),
            savedTowardMinor: saved,
            permille: Int(min(1000, saved * 1000 / target)),
            reached: saved >= target || achievedAtMs != nil
        )
    }

    private func quit(_ goal: GoalProgress?, savedMinor: Int64 = 0, elapsedMs: Int64? = nil) -> SmokingSnapshot {
        let elapsed = elapsedMs ?? day
        return .quit(QuitSnapshot(
            plan: plan,
            attemptId: "attempt",
            attemptStartedAtMs: 0,
            attemptElapsedMs: elapsed,
            sinceLastSmokeMs: elapsed,
            slipCount: 0,
            unitsNotSmoked: 0,
            unitsNotSmokedToday: 0,
            savedMinor: savedMinor,
            timeRegainedMinutes: 0,
            cravingsBeaten: 0,
            cravingsBeatenAllTime: 0,
            stages: [],
            nextStage: nil,
            attempts: [],
            goal: goal
        ))
    }

    private func reduce(_ goal: GoalProgress?, weekSavedMinor: Int64 = 0) -> SmokingSnapshot {
        .reduce(ReduceSnapshot(
            plan: SmokingPlan(
                id: "plan",
                mode: .reduce,
                productType: .cigarette,
                baselineUnitsPerDay: 20,
                dailyLimit: 10,
                currencyCode: "TRY",
                reason: nil,
                notificationsEnabled: true,
                eveningReminderEnabled: false,
                createdAtMs: 0,
                tzId: "Europe/Istanbul"
            ),
            todayEpochDay: 0,
            todayUnits: 0,
            todayHasEntry: false,
            dailyLimit: 10,
            last7Days: [],
            weekReductionUnits: 0,
            weekSavedMinor: weekSavedMinor,
            savedSinceSetupMinor: 0,
            cravingsBeatenAllTime: 0,
            stagesPreview: [],
            goal: goal
        ))
    }

    private func state(_ snapshot: SmokingSnapshot?, premium: Bool) -> SmokingMainUiState {
        SmokingMainUiState(snapshot: snapshot, isPremium: premium)
    }

    // MARK: Which card

    @Test("a free account sees the locked card whether or not a goal exists")
    func freeAccountSeesTheLockedCard() {
        #expect(state(quit(nil), premium: false).goalCard() == .locked)
        #expect(state(quit(progress(saved: 100_000)), premium: false).goalCard() == .locked)
        #expect(state(reduce(progress(saved: 100_000)), premium: false).goalCard() == .locked)
    }

    @Test("a premium account with no goal sees the first-goal card")
    func premiumWithNoGoalSeesTheFirstGoalCard() {
        #expect(state(quit(nil), premium: true).goalCard() == GoalCardState.none)
        #expect(state(reduce(nil), premium: true).goalCard() == GoalCardState.none)
    }

    @Test("a goal short of its target is in progress with the figures of the snapshot")
    func goalShortOfItsTargetIsInProgress() {
        let card = state(quit(progress(saved: 315_000), savedMinor: 315_000), premium: true).goalCard()

        guard case let .inProgress(goal) = card else {
            Issue.record("expected an in-progress card, got \(String(describing: card))")
            return
        }
        #expect(goal.title == "Yeni bisiklet")
        #expect(goal.savedMinor == 315_000)
        #expect(goal.targetMinor == 800_000)
        #expect(goal.permille == 393)
    }

    @Test("a goal at its target is reached")
    func goalAtItsTargetIsReached() {
        let card = state(quit(progress(saved: 800_000)), premium: true).goalCard()

        #expect(card == .reached(title: "Yeni bisiklet", targetMinor: 800_000))
    }

    @Test("a goal already stamped as achieved stays reached")
    func stampedGoalStaysReached() {
        let card = state(quit(progress(saved: 100_000, achievedAtMs: 5)), premium: true).goalCard()

        #expect(card == .reached(title: "Yeni bisiklet", targetMinor: 800_000))
    }

    @Test("there is no card without a plan")
    func noCardWithoutAPlan() {
        #expect(state(.notSetUp, premium: true).goalCard() == nil)
        #expect(state(nil, premium: true).goalCard() == nil)
    }

    // MARK: Estimate

    private func eta(_ state: SmokingMainUiState) -> Int64?? {
        guard case let .inProgress(goal) = state.goalCard() else { return .none }
        return .some(goal.etaDays)
    }

    @Test("quit estimates days from the attempt's average daily saving")
    func quitEstimatesFromTheAttemptsAverage() {
        // 100 000 saved over 10 days is 10 000 a day; 485 000 still to go is 49 days, rounded up.
        let card = state(quit(progress(saved: 315_000), savedMinor: 100_000, elapsedMs: 10 * day), premium: true)

        #expect(eta(card) == .some(49))
    }

    @Test("reduce estimates days from a seventh of the week's saving")
    func reduceEstimatesFromASeventhOfTheWeek() {
        // 7 000 over the week is 1 000 a day; 485 000 to go.
        let card = state(reduce(progress(saved: 315_000), weekSavedMinor: 7000), premium: true)

        #expect(eta(card) == .some(485))
    }

    @Test("no estimate while the rate is zero")
    func noEstimateWhileTheRateIsZero() {
        let quitCard = state(quit(progress(saved: 0), savedMinor: 0, elapsedMs: 10 * day), premium: true)
        let reduceCard = state(reduce(progress(saved: 0), weekSavedMinor: 0), premium: true)
        let brandNew = state(quit(progress(saved: 0), savedMinor: 5, elapsedMs: 0), premium: true)

        #expect(eta(quitCard) == .some(nil))
        #expect(eta(reduceCard) == .some(nil))
        #expect(eta(brandNew) == .some(nil), "no elapsed time, no rate")
    }

    @Test("a remainder under one day's rate still rounds up to a day")
    func remainderRoundsUpToADay() {
        #expect(goalEtaDays(remainingMinor: 1, dailyRateMinor: 5000) == 1)
        #expect(goalEtaDays(remainingMinor: 5001, dailyRateMinor: 5000) == 2)
        #expect(goalEtaDays(remainingMinor: 5000, dailyRateMinor: 5000) == 1)
        #expect(goalEtaDays(remainingMinor: 5000, dailyRateMinor: 0) == nil)
    }

    @Test("a twenty year attempt at sixty a day does not overflow the rate")
    func twentyYearAttemptDoesNotOverflow() {
        let elapsed = 20 * 365 * day
        let saved: Int64 = 20 * 365 * 60 * 10000
        let card = state(
            quit(progress(saved: 1, target: 2), savedMinor: saved, elapsedMs: elapsed),
            premium: true
        )

        #expect(eta(card) == .some(1))
    }
}
