// Ported 1:1 from `feature/vitals/src/test/kotlin/com/alicansekban/salus/feature/vitals/
// domain/usecase/SaveBloodPressureEntryUseCaseTest.kt`.
//
// Seven cases, in the Kotlin order, with the Kotlin inputs and the Kotlin expectations, plus one
// iOS-only case for the NaN divergence the weight use case already carries. Each cites the Kotlin
// line it comes from, so a change on either side that is not made on the other shows in the diff.

import Foundation
import SalusCommon
import SalusTesting
import Testing

@testable import FeatureVitals

@Suite("SaveBloodPressureEntryUseCase")
struct SaveBloodPressureEntryUseCaseTests {
    /// `SaveBloodPressureEntryUseCaseTest.kt:21` — 1_750_000_000_000 ms.
    private static let measuredAt = Date(epochMilliseconds: 1_750_000_000_000)
    /// `SaveBloodPressureEntryUseCaseTest.kt:22` — `TimeZone.of("Europe/Istanbul")`.
    private static let zone = FixedSalusClock.defaultZone

    private let repository: FakeVitalsRepository
    private let useCase: SaveBloodPressureEntryUseCase

    init() {
        // `SaveBloodPressureEntryUseCaseTest.kt:17-19`.
        let repository = FakeVitalsRepository()
        self.repository = repository
        useCase = SaveBloodPressureEntryUseCase(
            repository: repository,
            idGenerator: FixedIdGenerator(id: "generated-id")
        )
    }

    /// `SaveBloodPressureEntryUseCaseTest.kt:24-28` — the Kotlin test's `save(...)` helper.
    private func save(
        systolic: Double?,
        diastolic: Double?,
        pulse: Double? = nil
    ) async throws -> SaveBloodPressureEntryUseCase.Result {
        try await useCase(
            existingId: nil,
            systolic: systolic,
            diastolic: diastolic,
            pulse: pulse,
            measuredAt: Self.measuredAt,
            timeZone: Self.zone,
            note: nil
        )
    }

    /// `SaveBloodPressureEntryUseCaseTest.kt:30-35` — `null systolic or diastolic is rejected`.
    @Test("nil systolic or diastolic is rejected")
    func nilSystolicOrDiastolicIsRejected() async throws {
        #expect(try await save(systolic: nil, diastolic: 80.0) == .invalidSystolic)
        #expect(try await save(systolic: 120.0, diastolic: nil) == .invalidDiastolic)
        #expect(repository.currentBloodPressure().isEmpty)
    }

    /// `SaveBloodPressureEntryUseCaseTest.kt:37-43` — both bounds are inclusive.
    @Test("systolic boundaries are enforced")
    func systolicBoundariesAreEnforced() async throws {
        #expect(try await save(systolic: 59.9, diastolic: 40.0) == .invalidSystolic)
        #expect(try await save(systolic: 250.1, diastolic: 80.0) == .invalidSystolic)
        #expect(try await save(systolic: 60.0, diastolic: 40.0).isSaved)
        #expect(try await save(systolic: 250.0, diastolic: 80.0).isSaved)
    }

    /// `SaveBloodPressureEntryUseCaseTest.kt:45-51`.
    @Test("diastolic boundaries are enforced")
    func diastolicBoundariesAreEnforced() async throws {
        #expect(try await save(systolic: 120.0, diastolic: 29.9) == .invalidDiastolic)
        #expect(try await save(systolic: 200.0, diastolic: 150.1) == .invalidDiastolic)
        #expect(try await save(systolic: 120.0, diastolic: 30.0).isSaved)
        #expect(try await save(systolic: 200.0, diastolic: 150.0).isSaved)
    }

    /// `SaveBloodPressureEntryUseCaseTest.kt:53-58` — a strict `>`, so an equal pair is rejected.
    @Test("systolic must be strictly above diastolic")
    func systolicMustBeStrictlyAboveDiastolic() async throws {
        #expect(try await save(systolic: 90.0, diastolic: 90.0) == .systolicNotAboveDiastolic)
        #expect(try await save(systolic: 80.0, diastolic: 90.0) == .systolicNotAboveDiastolic)
        #expect(try await save(systolic: 91.0, diastolic: 90.0).isSaved)
    }

    /// `SaveBloodPressureEntryUseCaseTest.kt:60-69` — pulse is optional, and only a *present* one
    /// is range-checked.
    @Test("pulse boundaries are enforced only when present")
    func pulseBoundariesAreEnforcedOnlyWhenPresent() async throws {
        #expect(try await save(systolic: 120.0, diastolic: 80.0, pulse: 19.9) == .invalidPulse)
        #expect(try await save(systolic: 120.0, diastolic: 80.0, pulse: 250.1) == .invalidPulse)
        #expect(try await save(systolic: 120.0, diastolic: 80.0, pulse: 20.0).isSaved)
        #expect(try await save(systolic: 120.0, diastolic: 80.0, pulse: 250.0).isSaved)

        let withoutPulse = try await save(systolic: 120.0, diastolic: 80.0, pulse: nil)

        guard case let .saved(entry) = withoutPulse else {
            Issue.record("expected .saved, got \(withoutPulse)")
            return
        }
        #expect(entry.pulse == nil)
    }

    /// `SaveBloodPressureEntryUseCaseTest.kt:71-79`.
    @Test("new entry gets generated id and blank note becomes nil")
    func newEntryGetsGeneratedIdAndBlankNoteBecomesNil() async throws {
        let result = try await useCase(
            existingId: nil,
            systolic: 120.0,
            diastolic: 80.0,
            pulse: 60.0,
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
        let stored = try #require(repository.currentBloodPressure().first)
        #expect(repository.currentBloodPressure().count == 1)
        #expect(stored.systolic == 120.0)
    }

    /// `SaveBloodPressureEntryUseCaseTest.kt:81-91` — an edit updates the row rather than adding
    /// a second one.
    @Test("existing id is preserved on update")
    func existingIdIsPreservedOnUpdate() async throws {
        _ = try await useCase(
            existingId: "existing",
            systolic: 120.0,
            diastolic: 80.0,
            pulse: nil,
            measuredAt: Self.measuredAt,
            timeZone: Self.zone,
            note: nil
        )

        let result = try await useCase(
            existingId: "existing",
            systolic: 130.0,
            diastolic: 85.0,
            pulse: nil,
            measuredAt: Self.measuredAt,
            timeZone: Self.zone,
            note: nil
        )

        guard case let .saved(saved) = result else {
            Issue.record("expected .saved, got \(result)")
            return
        }
        #expect(saved.id == "existing")
        let stored = try #require(repository.currentBloodPressure().first)
        #expect(repository.currentBloodPressure().count == 1)
        #expect(stored.systolic == 130.0)
    }

    /// iOS-only, and deliberately not one of the seven Kotlin cases: Kotlin's
    /// `systolic < MIN || systolic > MAX` is false for NaN and `systolic <= diastolic` is false
    /// for NaN too, so Android stores a NaN reading where this rejects it. It is the same recorded
    /// divergence `SaveWeightEntryUseCaseTests.nanIsRejected` carries (Android backlog §11 A11),
    /// and it is reachable: `Double("nan")` is what a text field produces.
    @Test("NaN is rejected")
    func nanIsRejected() async throws {
        #expect(try await save(systolic: Double.nan, diastolic: 80.0) == .invalidSystolic)
        #expect(try await save(systolic: 120.0, diastolic: Double.nan) == .invalidDiastolic)
        #expect(try await save(systolic: 120.0, diastolic: 80.0, pulse: Double.nan) == .invalidPulse)
        #expect(repository.currentBloodPressure().isEmpty)
    }
}

extension SaveBloodPressureEntryUseCase.Result {
    /// The twin of Kotlin's `assertTrue(result is Result.Saved)`: the cases that only care *that*
    /// the reading was accepted say so without unwrapping an entry they do not look at.
    fileprivate var isSaved: Bool {
        if case .saved = self {
            return true
        }
        return false
    }
}
