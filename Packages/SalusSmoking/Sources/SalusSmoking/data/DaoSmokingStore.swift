// Twin of `core/smoking/.../data/RoomSmokingStore.kt`: ``SmokingStore`` over the GRDB DAO.
//
// Android serialises `mutate` blocks with a mutex and wraps them in `withTransaction`. Here one
// `SmokingDao.write(_:)` is both: GRDB's writer queue serialises the blocks, and the decision a
// use case makes from `input` is taken inside the same write transaction that applies it, so two
// racing taps cannot decide on the same stale rows.

import SalusDatabase

final class DaoSmokingStore: SmokingStore {
    private let dao: SmokingDao
    private let listeners: SmokingChangeListeners

    init(dao: SmokingDao, listeners: SmokingChangeListeners) {
        self.dao = dao
        self.listeners = listeners
    }

    func mutate<T: Sendable>(_ block: @escaping @Sendable (any SmokingWrites) throws -> T) async throws -> T {
        let (value, wrote) = try await dao.write { transaction in
            let writes = try DaoWrites(transaction: transaction, input: transaction.readInput())
            let value = try block(writes)
            return (value, writes.wrote)
        }
        // After the commit and outside the transaction: a listener that writes again must not find
        // the writer busy. A block that changed nothing (a repeated "none today", an idle repair)
        // leaves the reminders as they were.
        if wrote {
            listeners.notifyAll()
        }
        return value
    }
}

/// The writes of one `mutate` block. Lives only inside the block, because the transaction it holds
/// is only open there (`SmokingDao.Transaction` must not escape).
private final class DaoWrites: SmokingWrites {
    private let transaction: SmokingDao.Transaction
    let input: SmokingInput
    /// True once the block has issued any write; decides whether the listeners are told.
    private(set) var wrote = false

    init(transaction: SmokingDao.Transaction, input: SmokingInput) {
        self.transaction = transaction
        self.input = input
    }

    private func write(_ action: () throws -> Void) throws {
        wrote = true
        try action()
    }

    func savePlan(_ plan: SmokingPlan) throws {
        try write { try transaction.upsertPlan(plan.toRecord()) }
    }

    func addPricePeriod(_ period: PricePeriod) throws {
        try write { try transaction.insertPricePeriod(period.toRecord()) }
    }

    func updatePricePeriod(_ period: PricePeriod) throws {
        try write { try transaction.updatePricePeriod(period.toRecord()) }
    }

    func addAttempt(_ attempt: QuitAttempt) throws {
        try write { try transaction.insertAttempt(attempt.toRecord()) }
    }

    func updateAttempt(_ attempt: QuitAttempt) throws {
        try write { try transaction.updateAttempt(attempt.toRecord()) }
    }

    func addEvent(_ event: SmokingEvent) throws {
        try write { try transaction.insertEvent(event.toRecord()) }
    }

    func updateEvent(_ event: SmokingEvent) throws {
        try write { try transaction.updateEvent(event.toRecord()) }
    }

    func deleteEvent(id: String) throws {
        try write { try transaction.deleteEvent(id: id) }
    }

    func deleteZeroMarker(epochDay: Int64) throws {
        try write { try transaction.deleteZeroMarker(epochDay: epochDay) }
    }

    func saveGoal(_ goal: SavingsGoal) throws {
        try write { try transaction.upsertGoal(goal.toRecord()) }
    }

    func resetAll() throws {
        try write { try transaction.resetAll() }
    }
}

extension SmokingDao.Transaction {
    /// One read of the five tables, as the calculators take them — the twin of `readInput()`. Inside
    /// a transaction, so no write can commit between the five reads.
    func readInput() throws -> SmokingInput {
        try SmokingInput(
            plan: plan()?.toDomain(),
            prices: pricePeriods().map { try $0.toDomain() },
            attempts: attempts().map { try $0.toDomain() },
            events: events().map { try $0.toDomain() },
            goal: activeGoal()?.toDomain()
        )
    }
}
