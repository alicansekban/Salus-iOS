// No Kotlin counterpart file — the same narrowing as `HomePremiumStatus`, for the smoking card.
//
// Android's `HomeViewModel` takes `SmokingRepository`, `LogSmoked` and `DeleteEvent` separately
// (`HomeViewModel.kt`). Home reads one stream and performs two writes — the REDUCE "+1" and its
// undo — so iOS gives it one protocol with exactly those three members. The use cases are concrete
// structs over a store, which a ViewModel test could only fake by building a whole store; behind
// this seam the test fakes three methods and the production adapter
// (``SmokingCoreHomeSmoking``) is a one-liner each.

import SalusSmoking

/// What the dashboard's smoking card reads and writes.
public protocol HomeSmoking: Sendable {
    /// The calculator's answer, on subscription and again after every change (contract §2).
    func observeSnapshot() -> AsyncStream<SmokingSnapshot>

    /// One smoked unit at `atMs`; answers the new event's id so an undo can delete that row and
    /// nothing else, whatever day the clock shows by then (`LogSmoked`, contract §6).
    func logOneSmoked(atMs: Int64) async throws -> String

    /// Deletes one event by id (`DeleteEvent`, contract §6).
    func deleteEvent(eventId: String) async throws
}
