import Foundation

/// Renames the active goal and changes its target while it is still being saved for. The row keeps
/// its id and `createdAtMs`, so the progress already earned stays (contract §6, §8.17); only
/// ``SaveSavingsGoal`` starts a new goal that counts from now. A goal that is no longer the active
/// one, or that is already stamped as achieved, cannot be edited.
///
/// A target lowered to or below the amount already saved leaves `achievedAtMs` nil: the next
/// snapshot reads `reached`, and the screen stamps it as it does for any goal that gets there.
///
/// Twin of `core/smoking/.../usecase/UpdateSavingsGoal.kt`.
public struct UpdateSavingsGoal: Sendable {
    private let store: any SmokingStore

    public init(store: any SmokingStore) {
        self.store = store
    }

    public func callAsFunction(goalId: String, title: String, targetMinor: Int64) async throws {
        try await store.mutate { writes in
            _ = try writes.input.requirePlan()
            guard let goal = writes.input.goal, goal.id == goalId, goal.achievedAtMs == nil else {
                throw SmokingError.invalidInput
            }
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || targetMinor <= 0 {
                throw SmokingError.invalidInput
            }
            try writes.saveGoal(goal.edited(title: trimmed, targetMinor: targetMinor))
        }
    }
}
