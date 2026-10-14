import SalusCommon

/// Stamps the active goal as reached, once: a repeat keeps the first instant (contract §6).
public struct MarkGoalAchieved: Sendable {
    private let store: any SmokingStore
    private let clock: any SalusClock

    public init(store: any SmokingStore, clock: any SalusClock) {
        self.store = store
        self.clock = clock
    }

    public func callAsFunction(goalId: String) async throws {
        let clock = clock
        try await store.mutate { writes in
            guard let goal = writes.input.goal, goal.id == goalId else { throw SmokingError.invalidInput }
            if goal.achievedAtMs == nil {
                try writes.saveGoal(goal.achieved(at: clock.nowEpochMilliseconds()))
            }
        }
    }
}
