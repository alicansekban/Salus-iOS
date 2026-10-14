import SalusCommon

/// Opens a price period effective today; past days keep the price they had. A second update on the
/// same day replaces today's period instead of adding a competing one (contract §6).
public struct UpdatePrice: Sendable {
    private let store: any SmokingStore
    private let clock: any SalusClock
    private let idGenerator: any IdGenerator

    public init(store: any SmokingStore, clock: any SalusClock, idGenerator: any IdGenerator) {
        self.store = store
        self.clock = clock
        self.idGenerator = idGenerator
    }

    public func callAsFunction(unitCostMinor: Int64) async throws {
        let clock = clock
        let idGenerator = idGenerator
        try await store.mutate { writes in
            _ = try writes.input.requirePlan()
            if unitCostMinor < 0 {
                throw SmokingError.invalidInput
            }
            let today = clock.smokingTodayEpochDay
            if let current = writes.input.prices.first(where: { $0.effectiveFromEpochDay == today }) {
                try writes.updatePricePeriod(current.withUnitCost(unitCostMinor))
            } else {
                try writes.addPricePeriod(
                    PricePeriod(id: idGenerator.newId(), effectiveFromEpochDay: today, unitCostMinor: unitCostMinor)
                )
            }
        }
    }
}
