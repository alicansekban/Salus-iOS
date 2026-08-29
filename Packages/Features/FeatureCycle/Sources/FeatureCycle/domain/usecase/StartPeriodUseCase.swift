// Ported 1:1 from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/domain/
// usecase/StartPeriodUseCase.kt`.

import Foundation
import SalusCommon
import SalusModel

/// Opens a new period record for `startDate`, unless one is already running or that day is
/// already the start of a record (`StartPeriodUseCase.kt:11-41`).
///
/// There is no clock here and no reminder sync: `startDate` and `createdAt` are parameters, so
/// the caller decides what "today" is and the test can fix it, and the ViewModel is what asks the
/// reminder engine to re-sync after a write.
public struct StartPeriodUseCase: Sendable {
    /// `StartPeriodUseCase.kt:16-22`. Kotlin's `sealed interface` of one `data class` and two
    /// `data object`s is an enum with one associated value; both spellings are exhaustive and both
    /// compare by value.
    ///
    /// `Sendable` is the one addition: Kotlin's `data object`s are trivially shareable, and a
    /// public Swift enum gets no implicit conformance, so a caller that hops isolation between
    /// awaiting this and reading the result would not compile without it.
    public enum Result: Equatable, Sendable {
        case started(CyclePeriod)
        case alreadyActive
        case duplicateStart
    }

    private let repository: any CycleRepository
    private let idGenerator: any IdGenerator

    public init(repository: any CycleRepository, idGenerator: any IdGenerator) {
        self.repository = repository
        self.idGenerator = idGenerator
    }

    /// `StartPeriodUseCase.kt:24-41`. Kotlin's `operator fun invoke` is `callAsFunction`, so the
    /// call site reads `useCase(...)` on both platforms.
    ///
    /// The order of the two rejections is the Kotlin one and is load-bearing: a running period is
    /// reported as *already active* even when the user picked its own start date, because
    /// "you are already in a period" is the answer that tells them what to do next.
    public func callAsFunction(startDate: LocalDate, createdAt: Date) async throws -> Result {
        // `StartPeriodUseCase.kt:25-27` — two open periods at once would make `getOpenPeriod()`
        // ambiguous for every screen that reads it.
        if try await repository.getOpenPeriod() != nil {
            return .alreadyActive
        }
        // `StartPeriodUseCase.kt:28-30` — one record per start day, so the cycle-length history
        // the predictor reads cannot contain a zero-day gap.
        if try await repository.getPeriodStartingOn(startDate) != nil {
            return .duplicateStart
        }
        // `StartPeriodUseCase.kt:31-38` — a fresh record is open (no end date) and blank: the flow
        // peak and the note are filled in later, from the day logs and the editor.
        let period = CyclePeriod(
            id: idGenerator.newId(),
            startDate: startDate,
            endDate: nil,
            flowPeak: nil,
            note: nil,
            createdAt: createdAt
        )
        try await repository.savePeriod(period)
        return .started(period)
    }
}
