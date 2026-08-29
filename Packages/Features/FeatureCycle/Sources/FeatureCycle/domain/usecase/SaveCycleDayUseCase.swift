// Ported 1:1 from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/domain/
// usecase/SaveCycleDayUseCase.kt`.

import Foundation
import SalusCommon
import SalusModel

/// Writes the day log for one date, creating it or replacing the one already there
/// (`SaveCycleDayUseCase.kt:10-37`).
public struct SaveCycleDayUseCase: Sendable {
    /// `SaveCycleDayUseCase.kt:15-17`. Kotlin's `sealed interface` has the one `data class`, and
    /// so does this enum: the day log has nothing to reject — every field is optional and the date
    /// comes from the caller — but the shape stays a `Result` so a validation rule added on either
    /// platform lands in a type the call sites already switch over.
    public enum Result: Equatable, Sendable {
        case saved(CycleDayLog)
    }

    private let repository: any CycleRepository
    private let idGenerator: any IdGenerator

    public init(repository: any CycleRepository, idGenerator: any IdGenerator) {
        self.repository = repository
        self.idGenerator = idGenerator
    }

    /// `SaveCycleDayUseCase.kt:19-37`. Kotlin's `operator fun invoke` is `callAsFunction`, so the
    /// call site reads `useCase(...)` on both platforms.
    public func callAsFunction(
        date: LocalDate,
        flow: FlowLevel?,
        mood: Mood?,
        note: String?,
        symptomIds: Set<String>
    ) async throws -> Result {
        // `SaveCycleDayUseCase.kt:26-28` — the existing log's id is kept, so an edit updates the
        // row the user is looking at instead of leaving a second one behind.
        let existing = try await repository.getDayLog(on: date)
        let log = CycleDayLog(
            id: existing?.id ?? idGenerator.newId(),
            date: date,
            flow: flow,
            mood: mood,
            // `SaveCycleDayUseCase.kt:32` — `trim()?.takeIf { it.isNotEmpty() }`: a note of
            // nothing but whitespace is no note, so the day does not read as annotated.
            note: note?.trimmedOrNil,
            symptomIds: symptomIds
        )
        try await repository.saveDayLog(log)
        return .saved(log)
    }
}

extension String {
    /// The twin of Kotlin's `trim().takeIf { it.isNotEmpty() }` (`SaveCycleDayUseCase.kt:32`).
    /// Kotlin's `trim()` drops whitespace *and* line breaks, which is Foundation's
    /// `.whitespacesAndNewlines`.
    fileprivate var trimmedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
