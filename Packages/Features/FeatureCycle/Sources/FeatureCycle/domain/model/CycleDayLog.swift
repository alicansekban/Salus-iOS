// Ported 1:1 from Android
// `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/domain/model/CycleDayLog.kt`.

import SalusModel

/// Everything the user logged for a single day: flow, mood, note and symptom selections
/// (`CycleDayLog.kt:8-15`).
public struct CycleDayLog: Equatable, Hashable, Sendable {
    public let id: String
    public let date: LocalDate
    public let flow: FlowLevel?
    public let mood: Mood?
    public let note: String?
    /// Ids of the selected ``Symptom``s; Kotlin's `Set<String>` is a `Set<String>` here too, so
    /// selection order never leaks into equality.
    public let symptomIds: Set<String>

    public init(
        id: String,
        date: LocalDate,
        flow: FlowLevel?,
        mood: Mood?,
        note: String?,
        symptomIds: Set<String>
    ) {
        self.id = id
        self.date = date
        self.flow = flow
        self.mood = mood
        self.note = note
        self.symptomIds = symptomIds
    }
}
