// Ported 1:1 from `feature/cycle/src/test/kotlin/com/alicansekban/salus/feature/cycle/domain/
// usecase/EndPeriodUseCaseTest.kt`.
//
// Three cases, in the Kotlin order, with the Kotlin inputs and the Kotlin expectations. Each one
// cites the Kotlin line it comes from, so a change on either side that is not made on the other is
// visible in the diff.

import Foundation
import SalusModel
import Testing

@testable import FeatureCycle

@Suite("EndPeriodUseCase")
struct EndPeriodUseCaseTests {
    // `EndPeriodUseCaseTest.kt:16-17`.
    private let repository = FakeCycleRepository()
    private let useCase: EndPeriodUseCase

    // `EndPeriodUseCaseTest.kt:19-20`.
    private static let createdAt = Date(timeIntervalSince1970: 1_755_000_000)
    private static let startDate = LocalDate(year: 2026, month: 8, day: 10)

    init() {
        useCase = EndPeriodUseCase(repository: repository)
    }

    /// `EndPeriodUseCaseTest.kt:22-31` — the returned record and the stored one carry the same end
    /// date, so the screen and the database cannot disagree about whether the period is over.
    @Test("ending the open period stores its end date")
    func endingTheOpenPeriodStoresItsEndDate() async throws {
        repository.setPeriods(openPeriod())

        let result = try await useCase(endDate: LocalDate(year: 2026, month: 8, day: 15))

        let ended = try #require(Self.endedPeriod(result))
        #expect(ended.endDate == LocalDate(year: 2026, month: 8, day: 15))
        let stored = try #require(repository.currentPeriods().onlyElement)
        #expect(stored.endDate == LocalDate(year: 2026, month: 8, day: 15))
    }

    /// `EndPeriodUseCaseTest.kt:33-42` — an already-ended period is not an open one, so there is
    /// nothing to close.
    @Test("ending without an open period reports NoActivePeriod")
    func endingWithoutAnOpenPeriodReportsNoActivePeriod() async throws {
        repository.setPeriods(
            CyclePeriod(
                id: "done",
                startDate: Self.startDate,
                endDate: LocalDate(year: 2026, month: 8, day: 14),
                flowPeak: nil,
                note: nil,
                createdAt: Self.createdAt
            )
        )

        let result = try await useCase(endDate: LocalDate(year: 2026, month: 8, day: 15))

        #expect(result == .noActivePeriod)
    }

    /// `EndPeriodUseCaseTest.kt:44-52` — the open record stays open, so a mistyped date cannot
    /// close a period backwards.
    @Test("end date before the start date is rejected")
    func endDateBeforeTheStartDateIsRejected() async throws {
        repository.setPeriods(openPeriod())

        let result = try await useCase(endDate: LocalDate(year: 2026, month: 8, day: 9))

        #expect(result == .invalidEndDate)
        let stored = try #require(repository.currentPeriods().onlyElement)
        #expect(stored.endDate == nil)
    }

    /// `EndPeriodUseCaseTest.kt:24` — the one open record two of the three cases start from.
    private func openPeriod() -> CyclePeriod {
        CyclePeriod(
            id: "open",
            startDate: Self.startDate,
            endDate: nil,
            flowPeak: nil,
            note: nil,
            createdAt: Self.createdAt
        )
    }

    /// Kotlin's `(result as Result.Ended).period`, without the cast that crashes on the other two
    /// cases.
    private static func endedPeriod(_ result: EndPeriodUseCase.Result) -> CyclePeriod? {
        guard case let .ended(period) = result else { return nil }
        return period
    }
}

extension Collection {
    /// The twin of Kotlin's `single()`: the one element, or `nil` where Kotlin throws. Paired with
    /// `try #require` at the call site, so a list of two fails the test instead of reading the
    /// first and passing.
    var onlyElement: Element? {
        count == 1 ? first : nil
    }
}
