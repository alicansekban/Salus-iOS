import SalusCommon

/// Moves the active attempt's start. The attempt link of every entry is re-derived, so slips that
/// now fall before the start detach and entries the new window covers attach (contract §6). A start
/// earlier than the previous attempt's end is `invalidInput`: attempts never overlap.
public struct EditQuitDate: Sendable {
    private let store: any SmokingStore
    private let clock: any SalusClock

    public init(store: any SmokingStore, clock: any SalusClock) {
        self.store = store
        self.clock = clock
    }

    public func callAsFunction(newStartMs: Int64) async throws {
        let clock = clock
        try await store.mutate { writes in
            let input = writes.input
            _ = try input.requirePlan()
            guard let active = input.activeAttempt() else { throw SmokingError.invalidInput }
            if newStartMs > clock.nowEpochMilliseconds() {
                throw SmokingError.futureQuitDate
            }
            try input.requireNotBeforeClosedAttempts(except: active.id, startMs: newStartMs)

            let moved = active.startingAt(newStartMs)
            try writes.updateAttempt(moved)
            try writes.rederiveEvents(attempts: input.attempts.map { $0.id == moved.id ? moved : $0 })
        }
    }
}
