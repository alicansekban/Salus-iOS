/// Updates the settings screen's plan fields in one write: limit, reason and the two switches.
public struct UpdatePlanFields: Sendable {
    private let store: any SmokingStore

    public init(store: any SmokingStore) {
        self.store = store
    }

    /// `dailyLimit` is required (at least 1) for a REDUCE plan and ignored for QUIT, where the
    /// column stays null. A blank `reason` clears it.
    public func callAsFunction(
        dailyLimit: Int64?,
        reason: String?,
        notificationsEnabled: Bool,
        eveningReminderEnabled: Bool
    ) async throws {
        try await store.mutate { writes in
            let plan = try writes.input.requirePlan()
            let limit: Int64?
            switch plan.mode {
            case .reduce:
                guard let dailyLimit, dailyLimit >= 1 else { throw SmokingError.invalidInput }
                limit = dailyLimit

            case .quit:
                limit = nil
            }
            try writes.savePlan(
                plan.withSettings(
                    dailyLimit: limit,
                    reason: normalizedReason(reason),
                    notificationsEnabled: notificationsEnabled,
                    eveningReminderEnabled: eveningReminderEnabled
                )
            )
        }
    }
}
