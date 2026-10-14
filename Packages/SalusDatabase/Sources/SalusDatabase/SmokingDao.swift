// Ported 1:1 from `core/database/src/main/kotlin/com/alicansekban/salus/core/database/dao/SmokingDao.kt`
// (Android `2045f43`), contract §1 and the store readings of §8.6.
//
// Conventions — the plain struct over the database, the `@Query` strings carried verbatim, the
// conflated throwing stream standing in for Room's `Flow` — are `ProfileDao`'s and `CycleDao`'s.
//
// Three things are worth naming here.
//
// **Every write lives once, on `Transaction`.** Contract §6 runs each use case in one transaction,
// and Android's repository gets that from `db.withTransaction { … }` around suspend DAO calls. GRDB
// cannot nest a `write` inside a `write`, so the statements are `Transaction` methods over a
// `Database`, `write(_:)` hands one to a caller's block, and each public async method is that same
// statement in a transaction of its own. A use case and a single call therefore cannot drift apart.
//
// **`Transaction` also reads**, with the stream queries' exact SQL and order. A use case decides
// inside its transaction (which attempt is open, whether a plan exists), and must see what the
// screen sees — Android's suspend reads inside `withTransaction` give it the same.
//
// **`@Update` throws here when the id is missing**, where Room writes nothing: GRDB's update by
// primary key raises `RecordError.recordNotFound`. The same divergence, in the same safe direction,
// as `MedicationDao.updateIntakeLog`. `@Upsert` becomes GRDB's `upsert`: none of these tables has a
// unique index besides its primary key, which is the one place the two libraries differ (`CycleDao`).

import GRDB

/// Reads and writes the five smoking tables: the plan, its price history, quit attempts, the
/// event log, and savings goals.
public struct SmokingDao: Sendable {
    private let database: SalusDatabase

    public init(database: SalusDatabase) {
        self.database = database
    }

    // MARK: - Streams

    /// The plan, or nil before setup (`SmokingDao.kt` `observePlan`).
    public func observePlan() -> AsyncThrowingStream<SmokingPlanRecord?, any Error> {
        observe(Transaction.fetchPlan)
    }

    /// Oldest first; `id` breaks a tie so the order is total (`observePricePeriods`).
    public func observePricePeriods() -> AsyncThrowingStream<[SmokingPricePeriodRecord], any Error> {
        observe(Transaction.fetchPricePeriods)
    }

    /// Oldest first (`observeAttempts`).
    public func observeAttempts() -> AsyncThrowingStream<[SmokingQuitAttemptRecord], any Error> {
        observe(Transaction.fetchAttempts)
    }

    /// Oldest first (`observeEvents`).
    public func observeEvents() -> AsyncThrowingStream<[SmokingEventRecord], any Error> {
        observe(Transaction.fetchEvents)
    }

    /// The newest goal, reached or not (contract §8.6): a reached goal stays on the card until the
    /// next one is created, so `achieved_at_ms` must not filter it out (`observeActiveGoal`).
    public func observeActiveGoal() -> AsyncThrowingStream<SmokingSavingsGoalRecord?, any Error> {
        observe(Transaction.fetchActiveGoal)
    }

    // MARK: - Transaction

    /// Runs `body` as one transaction: all of its writes land, or none do.
    public func write<T: Sendable>(_ body: @escaping @Sendable (Transaction) throws -> T) async throws -> T {
        try await database.writer.write { db in
            try body(Transaction(db: db))
        }
    }

    // MARK: - Single writes

    /// `upsertPlan` — see `Transaction.upsertPlan`.
    public func upsertPlan(_ plan: SmokingPlanRecord) async throws {
        try await write { try $0.upsertPlan(plan) }
    }

    public func insertPricePeriod(_ period: SmokingPricePeriodRecord) async throws {
        try await write { try $0.insertPricePeriod(period) }
    }

    public func updatePricePeriod(_ period: SmokingPricePeriodRecord) async throws {
        try await write { try $0.updatePricePeriod(period) }
    }

    public func insertAttempt(_ attempt: SmokingQuitAttemptRecord) async throws {
        try await write { try $0.insertAttempt(attempt) }
    }

    public func updateAttempt(_ attempt: SmokingQuitAttemptRecord) async throws {
        try await write { try $0.updateAttempt(attempt) }
    }

    public func insertEvent(_ event: SmokingEventRecord) async throws {
        try await write { try $0.insertEvent(event) }
    }

    public func updateEvent(_ event: SmokingEventRecord) async throws {
        try await write { try $0.updateEvent(event) }
    }

    /// `deleteEvent` — see `Transaction.deleteEvent(id:)`.
    public func deleteEvent(id: String) async throws {
        try await write { try $0.deleteEvent(id: id) }
    }

    /// `deleteZeroMarker` — see `Transaction.deleteZeroMarker(epochDay:)`.
    public func deleteZeroMarker(epochDay: Int64) async throws {
        try await write { try $0.deleteZeroMarker(epochDay: epochDay) }
    }

    public func upsertGoal(_ goal: SmokingSavingsGoalRecord) async throws {
        try await write { try $0.upsertGoal(goal) }
    }

    /// `resetAll` — see `Transaction.resetAll()`.
    public func resetAll() async throws {
        try await write { try $0.resetAll() }
    }

    private func observe<Value: Sendable>(
        _ fetch: @escaping @Sendable (Database) throws -> Value
    ) -> AsyncThrowingStream<Value, any Error> {
        conflatedStream(ValueObservation.tracking(fetch).values(in: database.reader))
    }

    // MARK: - Transaction scope

    /// The statements of `SmokingDao`, bound to one open write transaction. Only reachable inside
    /// `SmokingDao.write(_:)`; it must not escape the block, as the `Database` under it does not.
    public struct Transaction {
        private let db: Database

        fileprivate init(db: Database) {
            self.db = db
        }

        // MARK: Reads

        public func plan() throws -> SmokingPlanRecord? {
            try Self.fetchPlan(db)
        }

        public func pricePeriods() throws -> [SmokingPricePeriodRecord] {
            try Self.fetchPricePeriods(db)
        }

        public func attempts() throws -> [SmokingQuitAttemptRecord] {
            try Self.fetchAttempts(db)
        }

        public func events() throws -> [SmokingEventRecord] {
            try Self.fetchEvents(db)
        }

        public func activeGoal() throws -> SmokingSavingsGoalRecord? {
            try Self.fetchActiveGoal(db)
        }

        // MARK: Writes

        /// Writes `plan` as the only plan (contract §8.6). The table is single-row by contract and
        /// the id is not fixed, so a plan arriving under a new id must replace the old row rather
        /// than sit beside it — otherwise `observePlan` would read whichever row SQLite returns
        /// first.
        public func upsertPlan(_ plan: SmokingPlanRecord) throws {
            try db.execute(sql: "DELETE FROM smoking_plan WHERE id != ?", arguments: [plan.id])
            try plan.upsert(db)
        }

        public func insertPricePeriod(_ period: SmokingPricePeriodRecord) throws {
            try period.insert(db)
        }

        public func updatePricePeriod(_ period: SmokingPricePeriodRecord) throws {
            try period.update(db)
        }

        public func insertAttempt(_ attempt: SmokingQuitAttemptRecord) throws {
            try attempt.insert(db)
        }

        public func updateAttempt(_ attempt: SmokingQuitAttemptRecord) throws {
            try attempt.update(db)
        }

        public func insertEvent(_ event: SmokingEventRecord) throws {
            try event.insert(db)
        }

        public func updateEvent(_ event: SmokingEventRecord) throws {
            try event.update(db)
        }

        /// By id, so an undo removes exactly the row it wrote, even after midnight.
        public func deleteEvent(id: String) throws {
            try db.execute(sql: "DELETE FROM smoking_event WHERE id = ?", arguments: [id])
        }

        /// Removes the REDUCE "none today" marker of `epochDay`; real entries of that day stay.
        public func deleteZeroMarker(epochDay: Int64) throws {
            try db.execute(
                sql: "DELETE FROM smoking_event WHERE epoch_day = ? AND units = 0",
                arguments: [epochDay]
            )
        }

        public func upsertGoal(_ goal: SmokingSavingsGoalRecord) throws {
            try goal.upsert(db)
        }

        /// `ResetSmoking` (contract §6): every row of the five tables. Events go before attempts,
        /// in Kotlin's order, so the `SET NULL` cascade has nothing left to rewrite.
        public func resetAll() throws {
            try db.execute(sql: "DELETE FROM smoking_event")
            try db.execute(sql: "DELETE FROM smoking_quit_attempt")
            try db.execute(sql: "DELETE FROM smoking_price_period")
            try db.execute(sql: "DELETE FROM smoking_savings_goal")
            try db.execute(sql: "DELETE FROM smoking_plan")
        }

        // MARK: Queries, shared with the streams

        fileprivate static func fetchPlan(_ db: Database) throws -> SmokingPlanRecord? {
            try SmokingPlanRecord.fetchOne(db, sql: "SELECT * FROM smoking_plan LIMIT 1")
        }

        fileprivate static func fetchPricePeriods(_ db: Database) throws -> [SmokingPricePeriodRecord] {
            try SmokingPricePeriodRecord.fetchAll(
                db,
                sql: "SELECT * FROM smoking_price_period ORDER BY effective_from_epoch_day ASC, id ASC"
            )
        }

        fileprivate static func fetchAttempts(_ db: Database) throws -> [SmokingQuitAttemptRecord] {
            try SmokingQuitAttemptRecord.fetchAll(
                db,
                sql: "SELECT * FROM smoking_quit_attempt ORDER BY started_at_ms ASC, id ASC"
            )
        }

        fileprivate static func fetchEvents(_ db: Database) throws -> [SmokingEventRecord] {
            try SmokingEventRecord.fetchAll(db, sql: "SELECT * FROM smoking_event ORDER BY occurred_at_ms ASC, id ASC")
        }

        fileprivate static func fetchActiveGoal(_ db: Database) throws -> SmokingSavingsGoalRecord? {
            try SmokingSavingsGoalRecord.fetchOne(
                db,
                sql: "SELECT * FROM smoking_savings_goal ORDER BY created_at_ms DESC, id DESC LIMIT 1"
            )
        }
    }
}
