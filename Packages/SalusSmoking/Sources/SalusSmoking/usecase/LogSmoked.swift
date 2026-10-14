// Twin of `core/smoking/.../usecase/{LogSmoked,LogNoneToday,LogCravingResisted}.kt` (contract §6).

import SalusCommon

/// Logs smoked units at `atMs`. The first +1 of a day deletes that day's "none today" marker.
/// Returns the event id, which an undo deletes by id.
public struct LogSmoked: Sendable {
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
        units: Int64,
        atMs: Int64,
        trigger: CravingTrigger? = nil,
        intensity: Int? = nil
    ) async throws -> String {
        let clock = clock
        let idGenerator = idGenerator
        return try await store.mutate { writes in
            let plan = try writes.input.requirePlan()
            if units < 1 {
                throw SmokingError.invalidInput
            }
            try requireIntensity(intensity)
            let event = newEvent(
                EventDraft(
                    id: idGenerator.newId(),
                    type: .smoked,
                    atMs: atMs,
                    units: units,
                    trigger: trigger,
                    intensity: intensity,
                    attemptId: writes.input.attemptId(at: atMs)
                ),
                clock: clock,
                plan: plan
            )
            try writes.addEvent(event)
            try writes.deleteZeroMarker(epochDay: event.epochDay)
            return event.id
        }
    }
}
