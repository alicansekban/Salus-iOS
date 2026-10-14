/// Deletes one entry **by id**, which is what an undo calls, so it removes exactly the row it
/// wrote even after midnight. An id that is already gone succeeds (a double-tapped undo). The
/// attempt link of the remaining entries is re-derived (contract §6).
public struct DeleteEvent: Sendable {
    private let store: any SmokingStore

    public init(store: any SmokingStore) {
        self.store = store
    }

    public func callAsFunction(eventId: String) async throws {
        try await store.mutate { writes in
            try writes.deleteEvent(id: eventId)
            try writes.rederiveEvents(
                attempts: writes.input.attempts,
                events: writes.input.events.filter { $0.id != eventId }
            )
        }
    }
}
