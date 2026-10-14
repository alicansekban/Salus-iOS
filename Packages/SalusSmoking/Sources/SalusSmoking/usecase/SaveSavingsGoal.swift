import Foundation
import SalusCommon

/// Creates the active savings goal; the newest row is the active one, so an older goal stays in the
/// table but stops being shown. Progress counts money accrued after the goal's creation (plan
/// ruling D4). Returns the goal id.
public struct SaveSavingsGoal: Sendable {
    private let store: any SmokingStore
    private let clock: any SalusClock
    private let idGenerator: any IdGenerator

    public init(store: any SmokingStore, clock: any SalusClock, idGenerator: any IdGenerator) {
        self.store = store
        self.clock = clock
        self.idGenerator = idGenerator
    }

    @discardableResult
    public func callAsFunction(title: String, targetMinor: Int64) async throws -> String {
        let clock = clock
        let idGenerator = idGenerator
        return try await store.mutate { writes in
            _ = try writes.input.requirePlan()
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || targetMinor <= 0 {
                throw SmokingError.invalidInput
            }
            let goal = SavingsGoal(
                id: idGenerator.newId(),
                title: trimmed,
                targetMinor: targetMinor,
                createdAtMs: clock.nowEpochMilliseconds(),
                achievedAtMs: nil
            )
            try writes.saveGoal(goal)
            return goal.id
        }
    }
}
