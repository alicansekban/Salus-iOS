/// Relabels the plan's currency. No conversion: there is no offline rate source (plan ruling D5).
public struct UpdateCurrency: Sendable {
    private let store: any SmokingStore

    public init(store: any SmokingStore) {
        self.store = store
    }

    public func callAsFunction(code: String) async throws {
        try await store.mutate { writes in
            let plan = try writes.input.requirePlan()
            try writes.savePlan(plan.withCurrency(normalizedCurrency(code)))
        }
    }
}
