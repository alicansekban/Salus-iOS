import Testing

@testable import SalusSmoking

/// Twin of the "Editing the active goal keeps its progress" region of Android's `SavingsGoalTest`
/// (contract §6, §8.17; parity D-M17-ae): an edit keeps the row's id and `createdAtMs`, so what was
/// already saved toward the goal stays.
@Suite("Editing the active goal", .timeLimit(.minutes(1)))
struct UpdateSavingsGoalTests {
    private let env: SmokingTestEnv

    init() throws {
        env = try SmokingTestEnv()
    }

    private func savedToward() async throws -> Int64 {
        switch await env.repository.snapshotNow() {
        case let .quit(snapshot): return try #require(snapshot.goal).savedTowardMinor
        case let .reduce(snapshot): return try #require(snapshot.goal).savedTowardMinor
        case .notSetUp:
            Issue.record("expected a plan snapshot")
            return -1
        }
    }

    @Test("an edit keeps the id, the creation instant and the progress")
    func keepsIdentityAndProgress() async throws {
        try await env.quitSetUp()
        let id = try await env.module.saveSavingsGoal(title: "Tatil", targetMinor: 250_000)
        env.at("2026-03-12T12:00")
        let before = try await savedToward()
        #expect(before != 0, "the fixture must have saved something by now")

        try await env.module.updateSavingsGoal(goalId: id, title: "  Bisiklet  ", targetMinor: 400_000)

        let goal = try #require(try await env.input().goal)
        #expect(goal.id == id)
        #expect(goal.createdAtMs == ms("2026-03-10T12:00"))
        #expect(goal.achievedAtMs == nil)
        #expect(goal.title == "Bisiklet")
        #expect(goal.targetMinor == 400_000)
        #expect(try await savedToward() == before)
    }

    @Test("lowering the target to what is saved leaves the goal open and reads as reached")
    func loweredTargetReadsAsReached() async throws {
        try await env.quitSetUp()
        let id = try await env.module.saveSavingsGoal(title: "Tatil", targetMinor: 250_000)
        env.at("2026-03-12T12:00")
        let saved = try await savedToward()

        try await env.module.updateSavingsGoal(goalId: id, title: "Tatil", targetMinor: saved)

        // The main view model stamps it, as for any goal that reaches its target.
        #expect(try await env.input().goal?.achievedAtMs == nil)
        guard case let .quit(snapshot) = await env.repository.snapshotNow() else {
            Issue.record("expected a quit snapshot")
            return
        }
        #expect(snapshot.goal?.reached == true)
    }

    @Test("an edit is refused for a blank title, a target of zero or less, a wrong id and no plan")
    func refusesInvalidEdits() async throws {
        await #expect(throws: SmokingError.notSetUp) {
            try await env.module.updateSavingsGoal(goalId: "any", title: "Tatil", targetMinor: 100)
        }

        try await env.quitSetUp()
        let id = try await env.module.saveSavingsGoal(title: "Tatil", targetMinor: 250_000)

        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.updateSavingsGoal(goalId: id, title: "   ", targetMinor: 100)
        }
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.updateSavingsGoal(goalId: id, title: "Bisiklet", targetMinor: 0)
        }
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.updateSavingsGoal(goalId: id, title: "Bisiklet", targetMinor: -5)
        }
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.updateSavingsGoal(goalId: "missing", title: "Bisiklet", targetMinor: 100)
        }
        let goal = try #require(try await env.input().goal)
        #expect(goal.title == "Tatil")
        #expect(goal.targetMinor == 250_000)
    }

    @Test("an achieved goal and a goal that is no longer the active one cannot be edited")
    func refusesAchievedAndSupersededGoals() async throws {
        try await env.quitSetUp()
        let first = try await env.module.saveSavingsGoal(title: "Tatil", targetMinor: 250_000)
        env.at("2026-03-11T10:00")
        try await env.module.markGoalAchieved(goalId: first)

        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.updateSavingsGoal(goalId: first, title: "Bisiklet", targetMinor: 100)
        }
        #expect(try await env.input().goal?.title == "Tatil")

        env.at("2026-03-12T10:00")
        let second = try await env.module.saveSavingsGoal(title: "Bisiklet", targetMinor: 1_000_000)

        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.updateSavingsGoal(goalId: first, title: "Tatil 2", targetMinor: 100)
        }
        #expect(try await env.input().goal?.id == second)
        #expect(try await env.input().goal?.title == "Bisiklet")
    }
}
