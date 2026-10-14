// Twin of `core/smoking/.../repository/SmokingStore.kt`.
//
// The write side the use cases share. It speaks domain types only, so records never reach a use
// case (architecture.md), and so a ViewModel test can back the real use cases with a fake.

/// Runs a use case's decision and its writes as one unit.
public protocol SmokingStore: Sendable {
    /// Runs `block` as one transaction: an error thrown by it rolls every write back, and the
    /// change listeners are told afterwards, only when the block succeeded and wrote something.
    /// ``SmokingWrites/input`` is what the tables held when the block started.
    func mutate<T: Sendable>(_ block: @escaping @Sendable (any SmokingWrites) throws -> T) async throws -> T
}

/// The writes a ``SmokingStore/mutate(_:)`` block may make. Valid only inside the block.
public protocol SmokingWrites {
    var input: SmokingInput { get }

    /// Writes `plan` as the only plan row.
    func savePlan(_ plan: SmokingPlan) throws
    func addPricePeriod(_ period: PricePeriod) throws
    func updatePricePeriod(_ period: PricePeriod) throws
    func addAttempt(_ attempt: QuitAttempt) throws
    func updateAttempt(_ attempt: QuitAttempt) throws
    func addEvent(_ event: SmokingEvent) throws
    func updateEvent(_ event: SmokingEvent) throws
    /// By id, so an undo removes exactly the row it wrote. A missing id is not an error.
    func deleteEvent(id: String) throws
    /// Removes the REDUCE "none today" marker of `epochDay`; real entries of that day stay.
    func deleteZeroMarker(epochDay: Int64) throws
    func saveGoal(_ goal: SavingsGoal) throws
    /// Deletes every row of the five tables.
    func resetAll() throws
}
