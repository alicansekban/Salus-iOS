import SalusCommon

/// Records a craving the user got through. Called only from "Geçti"; leaving the craving flow
/// early writes nothing (contract §6), which is the screen's job. Returns the event id.
public struct LogCravingResisted: Sendable {
    private let store: any SmokingStore
    private let clock: any SalusClock
    private let idGenerator: any IdGenerator

    public init(store: any SmokingStore, clock: any SalusClock, idGenerator: any IdGenerator) {
        self.store = store
        self.clock = clock
        self.idGenerator = idGenerator
    }

    @discardableResult
    public func callAsFunction(
        atMs: Int64,
        trigger: CravingTrigger? = nil,
        intensity: Int? = nil
    ) async throws -> String {
        let clock = clock
        let idGenerator = idGenerator
        return try await store.mutate { writes in
            let plan = try writes.input.requirePlan()
            try requireIntensity(intensity)
            let event = newEvent(
                EventDraft(
                    id: idGenerator.newId(),
                    type: .cravingResisted,
                    atMs: atMs,
                    units: nil,
                    trigger: trigger,
                    intensity: intensity,
                    attemptId: writes.input.attemptId(at: atMs)
                ),
                clock: clock,
                plan: plan
            )
            try writes.addEvent(event)
            return event.id
        }
    }
}
