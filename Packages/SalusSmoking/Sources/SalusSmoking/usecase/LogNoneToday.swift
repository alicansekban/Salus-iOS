import SalusCommon

/// REDUCE only: "I smoked none today" writes a `units == 0` marker so the day counts as logged
/// (contract §3.12). A no-op when today already has an entry, so a double tap writes once.
public struct LogNoneToday: Sendable {
    private let store: any SmokingStore
    private let clock: any SalusClock
    private let idGenerator: any IdGenerator

    public init(store: any SmokingStore, clock: any SalusClock, idGenerator: any IdGenerator) {
        self.store = store
        self.clock = clock
        self.idGenerator = idGenerator
    }

    public func callAsFunction() async throws {
        let clock = clock
        let idGenerator = idGenerator
        try await store.mutate { writes in
            let plan = try writes.input.requirePlan()
            if plan.mode != .reduce {
                throw SmokingError.invalidInput
            }
            let today = clock.smokingTodayEpochDay
            let hasEntry = writes.input.events.contains { $0.type == .smoked && $0.epochDay == today }
            if !hasEntry {
                let draft = EventDraft(
                    id: idGenerator.newId(),
                    type: .smoked,
                    atMs: clock.nowEpochMilliseconds(),
                    units: 0,
                    trigger: nil,
                    intensity: nil,
                    attemptId: nil
                )
                try writes.addEvent(newEvent(draft, clock: clock, plan: plan))
            }
        }
    }
}
