import SalusCommon

/// QUIT only: logs the slip inside the active attempt. With `restart` the attempt is closed with
/// `RESTARTED` at `atMs` and the next one opens at the same instant; the triggering event stays on
/// the attempt it closed (contract §6, §8.1). Returns the event id.
public struct ResolveSlip: Sendable {
    private let store: any SmokingStore
    private let clock: any SalusClock
    private let idGenerator: any IdGenerator

    public init(store: any SmokingStore, clock: any SalusClock, idGenerator: any IdGenerator) {
        self.store = store
        self.clock = clock
        self.idGenerator = idGenerator
    }

    @discardableResult
    public func callAsFunction(units: Int64, atMs: Int64, restart: Bool) async throws -> String {
        let clock = clock
        let idGenerator = idGenerator
        return try await store.mutate { writes in
            let input = writes.input
            let plan = try input.requirePlan()
            if plan.mode != .quit || units < 1 {
                throw SmokingError.invalidInput
            }
            guard let active = input.activeAttempt() else { throw SmokingError.invalidInput }
            // A restart ends the attempt at the slip's instant, which cannot precede its start.
            if restart, atMs < active.startedAtMs {
                throw SmokingError.invalidInput
            }

            let event = newEvent(
                EventDraft(
                    id: idGenerator.newId(),
                    type: .smoked,
                    atMs: atMs,
                    units: units,
                    trigger: nil,
                    intensity: nil,
                    attemptId: restart ? active.id : input.attemptId(at: atMs)
                ),
                clock: clock,
                plan: plan
            )
            try writes.addEvent(event)
            if restart {
                try writes.updateAttempt(active.closed(at: atMs, reason: .restarted))
                try writes.addAttempt(
                    QuitAttempt(
                        id: idGenerator.newId(),
                        startedAtMs: atMs,
                        tzId: clock.timeZone().identifier,
                        endedAtMs: nil,
                        endReason: nil
                    )
                )
            }
            return event.id
        }
    }
}
