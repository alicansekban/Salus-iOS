// Ported 1:1 from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/domain/
// usecase/EndPeriodUseCase.kt`.

import SalusModel

/// Closes the running period on `endDate` (`EndPeriodUseCase.kt:7-27`).
///
/// No clock and no reminder sync: `endDate` is a parameter, and the ViewModel is what asks the
/// reminder engine to re-sync after a write.
public struct EndPeriodUseCase: Sendable {
    /// `EndPeriodUseCase.kt:11-17`. Kotlin's `sealed interface` of one `data class` and two
    /// `data object`s is an enum with one associated value; both spellings are exhaustive and both
    /// compare by value.
    ///
    /// `Sendable` is the one addition, for `StartPeriodUseCase.Result`'s reason.
    public enum Result: Equatable, Sendable {
        case ended(CyclePeriod)
        case noActivePeriod
        case invalidEndDate
    }

    private let repository: any CycleRepository

    public init(repository: any CycleRepository) {
        self.repository = repository
    }

    /// `EndPeriodUseCase.kt:19-27`. Kotlin's `operator fun invoke` is `callAsFunction`, so the call
    /// site reads `useCase(...)` on both platforms.
    public func callAsFunction(endDate: LocalDate) async throws -> Result {
        // `EndPeriodUseCase.kt:20` — the elvis return: nothing is running, so there is nothing to
        // close.
        guard let open = try await repository.getOpenPeriod() else {
            return .noActivePeriod
        }
        // `EndPeriodUseCase.kt:21-23` — strictly *before* the start, so a period that starts and
        // ends on the same day is a one-day period and not an error.
        if endDate < open.startDate {
            return .invalidEndDate
        }
        // `EndPeriodUseCase.kt:24` — the same record with an end date, so its id, note and flow
        // peak survive the close.
        let ended = open.ended(on: endDate)
        try await repository.savePeriod(ended)
        return .ended(ended)
    }
}

extension CyclePeriod {
    /// The twin of Kotlin's `data class` `copy(endDate = endDate)` (`EndPeriodUseCase.kt:24`).
    /// Swift has no synthesised `copy`, and a memberwise call at the call site would bury the one
    /// field that changes under five that do not.
    fileprivate func ended(on endDate: LocalDate) -> CyclePeriod {
        CyclePeriod(
            id: id,
            startDate: startDate,
            endDate: endDate,
            flowPeak: flowPeak,
            note: note,
            createdAt: createdAt
        )
    }
}
