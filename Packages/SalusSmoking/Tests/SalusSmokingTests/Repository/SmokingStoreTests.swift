import Testing

import SalusDatabase

@testable import SalusSmoking

@Suite("DaoSmokingStore", .timeLimit(.minutes(1)))
struct SmokingStoreTests {
    private let env: SmokingTestEnv
    private let price = PricePeriod(id: "p1", effectiveFromEpochDay: day("2026-03-10"), unitCostMinor: 450)

    init() throws {
        env = try SmokingTestEnv()
    }

    private func makeStore(listeners: SmokingChangeListeners? = nil) -> DaoSmokingStore {
        DaoSmokingStore(dao: env.dao, listeners: listeners ?? env.module.changeListeners)
    }

    @Test("a failing block rolls back every write it made and notifies nobody")
    func failureRollsBack() async throws {
        let store = makeStore()
        let price = price

        await #expect(throws: SmokingStoreTestError.boom) {
            try await store.mutate { writes in
                try writes.addPricePeriod(price)
                try writes.addPricePeriod(PricePeriod(
                    id: "p2",
                    effectiveFromEpochDay: price.effectiveFromEpochDay,
                    unitCostMinor: 1
                ))
                throw SmokingStoreTestError.boom
            }
        }

        #expect(try await env.input().prices.isEmpty)
        #expect(env.notifications.value == 0)
    }

    @Test("a successful block commits all its writes and notifies once")
    func successCommitsAndNotifiesOnce() async throws {
        let store = makeStore()
        let first = price
        let second = PricePeriod(id: "p2", effectiveFromEpochDay: day("2026-03-11"), unitCostMinor: 500)

        try await store.mutate { writes in
            try writes.addPricePeriod(first)
            try writes.addPricePeriod(second)
        }

        #expect(try await env.input().prices.count == 2)
        #expect(env.notifications.value == 1)
    }

    @Test("a block that only reads tells nobody")
    func readOnlyBlockIsSilent() async throws {
        let store = makeStore()

        let plan = try await store.mutate { writes in writes.input.plan }

        #expect(plan == nil)
        #expect(env.notifications.value == 0)
    }

    @Test("the block sees the rows as they were when it started, inside the transaction")
    func blockSeesTheCurrentRows() async throws {
        try await env.reduceSetUp()
        let store = makeStore()

        let mode = try await store.mutate { writes in writes.input.plan?.mode }

        #expect(mode == .reduce)
    }

    @Test("with no listener bound, writes still work")
    func noListenerBound() async throws {
        let bare = try SmokingTestEnv(listenerBound: false)

        try await bare.reduceSetUp()
        try await bare.module.logSmoked(units: 1, atMs: ms("2026-03-10T11:00"))

        #expect(try await bare.input().events.count == 1)
        #expect(bare.notifications.value == 0)
    }

    @Test("every registered listener is told")
    func everyListenerIsTold() async throws {
        let listeners = SmokingChangeListeners()
        let other = NotificationCounter()
        listeners.add(env.notifications)
        listeners.add(other)
        let store = makeStore(listeners: listeners)
        let price = price

        try await store.mutate { writes in try writes.addPricePeriod(price) }

        #expect(env.notifications.value == 1)
        #expect(other.value == 1)
    }
}

enum SmokingStoreTestError: Error {
    case boom
}
