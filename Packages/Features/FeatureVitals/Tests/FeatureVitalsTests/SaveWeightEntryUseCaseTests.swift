// Ported 1:1 from `feature/vitals/src/test/kotlin/com/alicansekban/salus/feature/vitals/
// domain/usecase/SaveWeightEntryUseCaseTest.kt`.
//
// Six cases, in the Kotlin order, with the Kotlin inputs and the Kotlin expectations. Each one
// cites the Kotlin line it comes from, so a change on either side that is not made on the other
// is visible in the diff. The only wording change is `null` → `nil` in the first name.

import Foundation
import SalusCommon
import SalusTesting
import Testing

@testable import FeatureVitals

@Suite("SaveWeightEntryUseCase")
struct SaveWeightEntryUseCaseTests {
    /// `SaveWeightEntryUseCaseTest.kt:21` — 1_750_000_000_000 ms.
    private static let measuredAt = Date(timeIntervalSince1970: 1_750_000_000)
    /// `SaveWeightEntryUseCaseTest.kt:22` — `TimeZone.of("Europe/Istanbul")`, which is the zone
    /// `FixedSalusClock` already resolves (with a documented fallback, so no force unwrap here).
    private static let zone = FixedSalusClock.defaultZone

    private let repository: FakeVitalsRepository
    private let useCase: SaveWeightEntryUseCase

    init() {
        // `SaveWeightEntryUseCaseTest.kt:17-19`.
        let repository = FakeVitalsRepository()
        self.repository = repository
        useCase = SaveWeightEntryUseCase(
            repository: repository,
            idGenerator: FixedIdGenerator(id: "generated-id")
        )
    }

    /// `SaveWeightEntryUseCaseTest.kt:24-30` — `null weight is rejected`.
    @Test("nil weight is rejected")
    func nilWeightIsRejected() async throws {
        let result = try await useCase(
            existingId: nil,
            kilograms: nil,
            measuredAt: Self.measuredAt,
            timeZone: Self.zone,
            note: nil
        )

        #expect(result == .invalidWeight)
        #expect(repository.current().isEmpty)
    }

    /// `SaveWeightEntryUseCaseTest.kt:32-42`.
    @Test("weight outside human range is rejected")
    func weightOutsideHumanRangeIsRejected() async throws {
        let tooLight = try await useCase(
            existingId: nil,
            kilograms: 10.0,
            measuredAt: Self.measuredAt,
            timeZone: Self.zone,
            note: nil
        )
        let tooHeavy = try await useCase(
            existingId: nil,
            kilograms: 500.0,
            measuredAt: Self.measuredAt,
            timeZone: Self.zone,
            note: nil
        )

        #expect(tooLight == .invalidWeight)
        #expect(tooHeavy == .invalidWeight)
    }

    /// `SaveWeightEntryUseCaseTest.kt:44-52`.
    @Test("new entry gets generated id and blank note becomes nil")
    func newEntryGetsGeneratedIdAndBlankNoteBecomesNil() async throws {
        let result = try await useCase(
            existingId: nil,
            kilograms: 82.5,
            measuredAt: Self.measuredAt,
            timeZone: Self.zone,
            note: "   "
        )

        guard case let .saved(saved) = result else {
            Issue.record("expected .saved, got \(result)")
            return
        }
        #expect(saved.id == "generated-id")
        #expect(saved.note == nil)
        let stored = try #require(repository.current().first)
        #expect(repository.current().count == 1)
        #expect(stored.kilograms == 82.5)
    }

    /// `SaveWeightEntryUseCaseTest.kt:54-62`.
    @Test("recordWeight writes through the same validation")
    func recordWeightWritesThroughTheSameValidation() async throws {
        let written = try await useCase.recordWeight(
            kilograms: 72.4,
            epochMs: Self.measuredAt.epochMilliseconds,
            timeZoneId: Self.zone.identifier
        )

        #expect(written)
        let saved = try #require(repository.current().first)
        #expect(repository.current().count == 1)
        #expect(saved.kilograms == 72.4)
        #expect(saved.measuredAt == Self.measuredAt)
        #expect(saved.timeZone == Self.zone)
    }

    /// `SaveWeightEntryUseCaseTest.kt:64-69`.
    @Test("recordWeight rejects an out of range value without writing")
    func recordWeightRejectsAnOutOfRangeValueWithoutWriting() async throws {
        let written = try await useCase.recordWeight(
            kilograms: 4.0,
            epochMs: Self.measuredAt.epochMilliseconds,
            timeZoneId: Self.zone.identifier
        )

        #expect(!written)
        #expect(repository.current().isEmpty)
    }

    /// `SaveWeightEntryUseCaseTest.kt:71-81`.
    @Test("existing id is preserved on update")
    func existingIdIsPreservedOnUpdate() async throws {
        _ = try await useCase(
            existingId: "existing",
            kilograms: 80.0,
            measuredAt: Self.measuredAt,
            timeZone: Self.zone,
            note: "before"
        )

        let result = try await useCase(
            existingId: "existing",
            kilograms: 81.0,
            measuredAt: Self.measuredAt,
            timeZone: Self.zone,
            note: "after"
        )

        guard case let .saved(saved) = result else {
            Issue.record("expected .saved, got \(result)")
            return
        }
        #expect(saved.id == "existing")
        let stored = try #require(repository.current().first)
        #expect(repository.current().count == 1)
        #expect(stored.kilograms == 81.0)
    }
}

/// The twin of Kotlin's SAM-converted `IdGenerator { "generated-id" }`
/// (`SaveWeightEntryUseCaseTest.kt:18`): every id the use case asks for is the same fixed string,
/// so the assertion on it is an assertion and not a guess.
struct FixedIdGenerator: IdGenerator {
    let id: String

    func newId() -> String {
        id
    }
}
