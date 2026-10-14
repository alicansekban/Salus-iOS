/// Edits an entry's time, units, trigger and intensity. The day is recomputed from the event's
/// **own** zone, never the device's current one, and its attempt link is re-derived (contract §1, §6).
public struct EditEvent: Sendable {
    private let store: any SmokingStore

    public init(store: any SmokingStore) {
        self.store = store
    }

    /// `units` is read for a SMOKED event only (at least 1); a craving keeps no unit count.
    public func callAsFunction(
        eventId: String,
        atMs: Int64,
        units: Int64?,
        trigger: CravingTrigger?,
        intensity: Int?
    ) async throws {
        try await store.mutate { writes in
            let input = writes.input
            _ = try input.requirePlan()
            guard let event = input.events.first(where: { $0.id == eventId }) else { throw SmokingError.invalidInput }
            try requireIntensity(intensity)
            let isMarker = event.type == .smoked && event.units == 0
            let newUnits: Int64?
            switch event.type {
            case .smoked:
                // A marker may stay a marker (only its time changes) or become a real entry; a real
                // entry can never be turned into a marker, which is what LogNoneToday is for.
                guard let units, units >= 1 || (isMarker && units == 0) else { throw SmokingError.invalidInput }
                newUnits = units

            case .cravingResisted:
                newUnits = nil
            }
            guard let editedDay = eventEpochDay(atMs: atMs, tzId: event.tzId) else { throw SmokingError.invalidInput }
            let edited = event.edited(
                occurredAtMs: atMs, epochDay: editedDay, units: newUnits, trigger: trigger, intensity: intensity
            )
            var remaining = input.events.map { $0.id == eventId ? edited : $0 }
            if edited.units == 0 {
                // A marker means "logged, smoked none": it cannot join a day that already has an entry.
                let taken = edited.epochDay != event.epochDay
                    && input.events.contains { $0.type == .smoked && $0.epochDay == edited.epochDay }
                if taken {
                    throw SmokingError.invalidInput
                }
            } else if edited.type == .smoked, !(isMarker && edited.epochDay == event.epochDay) {
                // A real entry on a day replaces that day's marker, wherever it was moved to. When the
                // edited event *is* the day's marker the row is updated in place instead: deleting it
                // here would leave `updateEvent` with nothing to update.
                try writes.deleteZeroMarker(epochDay: edited.epochDay)
                remaining.removeAll { $0.units == 0 && $0.epochDay == edited.epochDay && $0.id != eventId }
            }
            try writes.rederiveEvents(attempts: input.attempts, events: remaining)
        }
    }
}
