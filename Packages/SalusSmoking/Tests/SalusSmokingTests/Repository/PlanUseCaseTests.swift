import Testing

@testable import SalusSmoking

@Suite("Price, currency and plan fields", .timeLimit(.minutes(1)))
struct PlanUseCaseTests {
    private let env: SmokingTestEnv

    init() throws {
        env = try SmokingTestEnv()
    }

    @Test("a price change opens a period effective today and past days keep the old one")
    func priceOpensAPeriod() async throws {
        try await env.quitSetUp()
        env.at("2026-03-11T09:00")

        try await env.module.updatePrice(unitCostMinor: 6000)

        let prices = try await env.input().prices
        #expect(prices.map(\.effectiveFromEpochDay) == [day("2026-03-10"), day("2026-03-11")])
        #expect(prices.map(\.unitCostMinor) == [5000, 6000])
    }

    @Test("a second update on the same day replaces today's period instead of adding one")
    func sameDayPriceReplaces() async throws {
        try await env.quitSetUp()
        try await env.module.updatePrice(unitCostMinor: 6000)
        let first = try await env.input().prices

        try await env.module.updatePrice(unitCostMinor: 6500)

        let prices = try await env.input().prices
        #expect(prices.count == 1)
        #expect(prices.first?.id == first.first?.id)
        #expect(prices.first?.unitCostMinor == 6500)
    }

    @Test("a negative price, or no plan, fails")
    func priceFailures() async throws {
        await #expect(throws: SmokingError.notSetUp) {
            try await env.module.updatePrice(unitCostMinor: 100)
        }

        try await env.quitSetUp()
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.updatePrice(unitCostMinor: -1)
        }
    }

    @Test("a currency change relabels the plan and nothing else")
    func currencyRelabels() async throws {
        try await env.quitSetUp()
        let before = try await env.input()

        try await env.module.updateCurrency(code: "eur")

        let after = try await env.input()
        #expect(after.plan?.currencyCode == "EUR")
        #expect(after.prices == before.prices)
        #expect(after.attempts == before.attempts)
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.updateCurrency(code: "EURO")
        }
    }

    @Test("plan fields update the limit, reason and both switches in one write")
    func planFields() async throws {
        try await env.reduceSetUp()
        let before = env.notifications.value

        try await env.module.updatePlanFields(
            dailyLimit: 5, reason: "  my reason ", notificationsEnabled: false, eveningReminderEnabled: true
        )

        let plan = try #require(try await env.input().plan)
        #expect(plan.dailyLimit == 5)
        #expect(plan.reason == "my reason")
        #expect(plan.notificationsEnabled == false)
        #expect(plan.eveningReminderEnabled == true)
        #expect(env.notifications.value == before + 1)
    }

    @Test("a quit plan keeps its limit null, and a reduce plan needs one")
    func limitRules() async throws {
        try await env.quitSetUp()
        try await env.module.updatePlanFields(
            dailyLimit: 9, reason: "", notificationsEnabled: true, eveningReminderEnabled: false
        )
        let quit = try #require(try await env.input().plan)
        #expect(quit.dailyLimit == nil)
        #expect(quit.reason == nil)

        let reduce = try SmokingTestEnv()
        try await reduce.reduceSetUp()
        await #expect(throws: SmokingError.invalidInput) {
            try await reduce.module.updatePlanFields(
                dailyLimit: nil, reason: nil, notificationsEnabled: true, eveningReminderEnabled: false
            )
        }
    }
}

@Suite("Savings goal", .timeLimit(.minutes(1)))
struct SavingsGoalTests {
    private let env: SmokingTestEnv

    init() throws {
        env = try SmokingTestEnv()
    }

    @Test("saving a goal returns its id and makes it the active one")
    func savesAGoal() async throws {
        try await env.quitSetUp()

        let id = try await env.module.saveSavingsGoal(title: "  A bike ", targetMinor: 100_000)

        let goal = try #require(try await env.input().goal)
        #expect(goal.id == id)
        #expect(goal.title == "A bike")
        #expect(goal.targetMinor == 100_000)
        #expect(goal.createdAtMs == ms("2026-03-10T12:00"))
        #expect(goal.achievedAtMs == nil)
    }

    @Test("a newer goal replaces the active one, an empty title or zero target is invalid")
    func newestGoalWins() async throws {
        try await env.quitSetUp()
        try await env.module.saveSavingsGoal(title: "First", targetMinor: 1000)
        env.at("2026-03-11T12:00")

        let second = try await env.module.saveSavingsGoal(title: "Second", targetMinor: 2000)

        #expect(try await env.input().goal?.id == second)
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.saveSavingsGoal(title: "   ", targetMinor: 1000)
        }
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.saveSavingsGoal(title: "Zero", targetMinor: 0)
        }
    }

    @Test("marking a goal achieved stamps it once and keeps the first instant")
    func achievedOnce() async throws {
        try await env.quitSetUp()
        let id = try await env.module.saveSavingsGoal(title: "Goal", targetMinor: 1000)
        env.at("2026-03-12T09:00")

        try await env.module.markGoalAchieved(goalId: id)
        env.at("2026-03-13T09:00")
        try await env.module.markGoalAchieved(goalId: id)

        let goal = try #require(try await env.input().goal)
        #expect(goal.achievedAtMs == ms("2026-03-12T09:00"))
        // An achieved goal stays the active one until the next one is saved (contract §8.6).
        #expect(goal.id == id)
    }

    @Test("marking a goal that is not the active one is invalid")
    func unknownGoal() async throws {
        try await env.quitSetUp()
        try await env.module.saveSavingsGoal(title: "Goal", targetMinor: 1000)

        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.markGoalAchieved(goalId: "missing")
        }
    }
}

@Suite("ResetSmoking", .timeLimit(.minutes(1)))
struct ResetSmokingTests {
    private let env: SmokingTestEnv

    init() throws {
        env = try SmokingTestEnv()
    }

    @Test("it empties all five tables and tells the listener")
    func resetEmptiesAndNotifies() async throws {
        try await env.quitSetUp()
        try await env.module.resolveSlip(units: 1, atMs: ms("2026-03-09T10:00"), restart: true)
        try await env.module.logCravingResisted(atMs: ms("2026-03-09T11:00"))
        try await env.module.saveSavingsGoal(title: "Goal", targetMinor: 1000)
        let before = env.notifications.value

        try await env.module.resetSmoking()

        let input = try await env.input()
        #expect(input.plan == nil)
        #expect(input.prices.isEmpty)
        #expect(input.attempts.isEmpty)
        #expect(input.events.isEmpty)
        #expect(input.goal == nil)
        #expect(env.notifications.value == before + 1)
        #expect(await env.repository.snapshotNow() == .notSetUp)
    }
}
