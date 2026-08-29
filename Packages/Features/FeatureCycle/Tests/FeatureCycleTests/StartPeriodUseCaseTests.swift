// Ported 1:1 from `feature/cycle/src/test/kotlin/com/alicansekban/salus/feature/cycle/domain/
// usecase/StartPeriodUseCaseTest.kt`.
//
// Three cases, in the Kotlin order, with the Kotlin inputs and the Kotlin expectations. Each one
// cites the Kotlin line it comes from, so a change on either side that is not made on the other is
// visible in the diff.

import Foundation
import SalusCommon
import SalusModel
import Testing

@testable import FeatureCycle

@Suite("StartPeriodUseCase")
struct StartPeriodUseCaseTests {
    // `StartPeriodUseCaseTest.kt:18-19`.
    private let repository = FakeCycleRepository()
    private let useCase: StartPeriodUseCase

    // `StartPeriodUseCaseTest.kt:21-22`.
    private static let today = LocalDate(year: 2026, month: 8, day: 16)
    private static let createdAt = Date(timeIntervalSince1970: 1_755_000_000)

    init() {
        useCase = StartPeriodUseCase(
            repository: repository,
            idGenerator: FixedIdGenerator(id: "generated-id")
        )
    }

    /// `StartPeriodUseCaseTest.kt:24-33`.
    @Test("starting a period creates an open record with generated id")
    func startingAPeriodCreatesAnOpenRecordWithGeneratedId() async throws {
        let result = try await useCase(startDate: Self.today, createdAt: Self.createdAt)

        let started = try #require(Self.startedPeriod(result))
        #expect(started.id == "generated-id")
        #expect(started.startDate == Self.today)
        #expect(started.endDate == nil)
        #expect(repository.currentPeriods().count == 1)
    }

    /// `StartPeriodUseCaseTest.kt:35-45` — nothing is written, so a second tap on "start" cannot
    /// leave two periods running at once.
    @Test("starting while another period is open is rejected")
    func startingWhileAnotherPeriodIsOpenIsRejected() async throws {
        repository.setPeriods(
            CyclePeriod(
                id: "open",
                startDate: LocalDate(year: 2026, month: 8, day: 10),
                endDate: nil,
                flowPeak: nil,
                note: nil,
                createdAt: Self.createdAt
            )
        )

        let result = try await useCase(startDate: Self.today, createdAt: Self.createdAt)

        #expect(result == .alreadyActive)
        #expect(repository.currentPeriods().count == 1)
    }

    /// `StartPeriodUseCaseTest.kt:47-57` — the existing record is left exactly as it was.
    @Test("starting on a date that already has a period start is rejected")
    func startingOnADateThatAlreadyHasAPeriodStartIsRejected() async throws {
        repository.setPeriods(
            CyclePeriod(
                id: "done",
                startDate: Self.today,
                endDate: Self.today,
                flowPeak: nil,
                note: nil,
                createdAt: Self.createdAt
            )
        )

        let result = try await useCase(startDate: Self.today, createdAt: Self.createdAt)

        #expect(result == .duplicateStart)
        #expect(repository.currentPeriods().map(\.id) == ["done"])
    }

    /// Kotlin's `(result as Result.Started).period`, without the cast that crashes on the other
    /// two cases.
    private static func startedPeriod(_ result: StartPeriodUseCase.Result) -> CyclePeriod? {
        guard case let .started(period) = result else { return nil }
        return period
    }
}

/// The twin of Kotlin's SAM-converted `IdGenerator { "generated-id" }`
/// (`StartPeriodUseCaseTest.kt:19`): every id the use case asks for is the same fixed string, so
/// the assertion on it is an assertion and not a guess. A duplicate of the `FeatureVitals` and
/// `FeatureAppointments` test helpers of the same name — features never depend on each other, and
/// this lives in a test target.
struct FixedIdGenerator: IdGenerator {
    let id: String

    func newId() -> String {
        id
    }
}
