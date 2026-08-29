// Ported 1:1 from `feature/cycle/src/test/kotlin/com/alicansekban/salus/feature/cycle/domain/
// usecase/SaveCycleDayUseCaseTest.kt`.
//
// Two cases, in the Kotlin order, with the Kotlin inputs and the Kotlin expectations. Each one
// cites the Kotlin line it comes from, so a change on either side that is not made on the other is
// visible in the diff.

import SalusModel
import Testing

@testable import FeatureCycle

@Suite("SaveCycleDayUseCase")
struct SaveCycleDayUseCaseTests {
    // `SaveCycleDayUseCaseTest.kt:15-16`.
    private let repository = FakeCycleRepository()
    private let useCase: SaveCycleDayUseCase

    // `SaveCycleDayUseCaseTest.kt:18`.
    private static let date = LocalDate(year: 2026, month: 8, day: 16)

    init() {
        useCase = SaveCycleDayUseCase(
            repository: repository,
            idGenerator: FixedIdGenerator(id: "generated-id")
        )
    }

    /// `SaveCycleDayUseCaseTest.kt:20-35`.
    @Test("new day log gets generated id and blank note becomes null")
    func newDayLogGetsGeneratedIdAndBlankNoteBecomesNull() async throws {
        let result = try await useCase(
            date: Self.date,
            flow: .medium,
            mood: .low,
            note: "   ",
            symptomIds: ["symptom-cramps"]
        )

        let saved = Self.savedLog(result)
        #expect(saved.id == "generated-id")
        #expect(saved.note == nil)
        #expect(saved.symptomIds == ["symptom-cramps"])
        let stored = try #require(repository.currentDayLogs().onlyElement)
        #expect(stored.flow == .medium)
    }

    /// `SaveCycleDayUseCaseTest.kt:37-48` — the second save overwrites the day rather than adding
    /// a second log, and it clears the symptom selection the first one made.
    @Test("existing day log keeps its id on update")
    func existingDayLogKeepsItsIdOnUpdate() async throws {
        _ = try await useCase(
            date: Self.date,
            flow: .light,
            mood: nil,
            note: "first",
            symptomIds: ["symptom-cramps"]
        )

        let result = try await useCase(
            date: Self.date,
            flow: .heavy,
            mood: .good,
            note: "second",
            symptomIds: []
        )

        let saved = Self.savedLog(result)
        #expect(saved.id == "generated-id")
        #expect(repository.currentDayLogs().count == 1)
        let stored = try #require(repository.currentDayLogs().onlyElement)
        #expect(stored.note == "second")
        #expect(stored.symptomIds.isEmpty)
    }

    /// Kotlin's `(result as Result.Saved).log`. `Result` has the one case, so the `switch` is
    /// total and needs no failure branch — and a second case added on either platform stops this
    /// file compiling, which is the point.
    private static func savedLog(_ result: SaveCycleDayUseCase.Result) -> CycleDayLog {
        switch result {
        case let .saved(log): log
        }
    }
}
