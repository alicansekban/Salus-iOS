// Ported 1:1 from `feature/vitals/src/test/kotlin/com/alicansekban/salus/feature/vitals/
// domain/usecase/SaveGlucoseEntryUseCaseTest.kt`.
//
// Six cases, in the Kotlin order, with the Kotlin inputs and the Kotlin expectations, plus one
// iOS-only case for the NaN divergence the weight use case already carries.

import Foundation
import SalusCommon
import SalusModel
import SalusTesting
import Testing

@testable import FeatureVitals

@Suite("SaveGlucoseEntryUseCase")
struct SaveGlucoseEntryUseCaseTests {
    /// `SaveGlucoseEntryUseCaseTest.kt:24` — 1_750_000_000_000 ms.
    private static let measuredAt = Date(epochMilliseconds: 1_750_000_000_000)
    /// `SaveGlucoseEntryUseCaseTest.kt:25` — `TimeZone.of("Europe/Istanbul")`.
    private static let zone = FixedSalusClock.defaultZone

    private let repository: FakeVitalsRepository
    private let useCase: SaveGlucoseEntryUseCase

    init() {
        // `SaveGlucoseEntryUseCaseTest.kt:20-22`.
        let repository = FakeVitalsRepository()
        self.repository = repository
        useCase = SaveGlucoseEntryUseCase(
            repository: repository,
            idGenerator: FixedIdGenerator(id: "generated-id")
        )
    }

    /// `SaveGlucoseEntryUseCaseTest.kt:27-31` — the Kotlin test's `save(...)` helper.
    private func save(
        value: Double?,
        unit: GlucoseUnit = .mgDl,
        context: MeasurementContext? = nil
    ) async throws -> SaveGlucoseEntryUseCase.Result {
        try await useCase(
            existingId: nil,
            value: value,
            unit: unit,
            measuredAt: Self.measuredAt,
            timeZone: Self.zone,
            measurementContext: context,
            note: nil
        )
    }

    /// `SaveGlucoseEntryUseCaseTest.kt:33-37` — `null value is rejected`.
    @Test("nil value is rejected")
    func nilValueIsRejected() async throws {
        #expect(try await save(value: nil) == .invalidValue)
        #expect(repository.currentGlucose().isEmpty)
    }

    /// `SaveGlucoseEntryUseCaseTest.kt:39-45` — both bounds are inclusive.
    @Test("mg dL boundaries are enforced")
    func mgDlBoundariesAreEnforced() async throws {
        #expect(try await save(value: 19.9) == .invalidValue)
        #expect(try await save(value: 600.1) == .invalidValue)
        #expect(try await save(value: 20.0).isSaved)
        #expect(try await save(value: 600.0).isSaved)
    }

    /// `SaveGlucoseEntryUseCaseTest.kt:47-65` — the conversion runs *before* the range check, so
    /// a mmol/L reading is judged against the canonical mg/dL bounds rather than against numbers
    /// that would mean something else in its own unit.
    @Test("mmol L values are converted to canonical mg dL before validation")
    func mmolLValuesAreConvertedToCanonicalMgDlBeforeValidation() async throws {
        // 5.5 mmol/L = 99.1 mg/dL -> valid
        let result = try await save(value: 5.5, unit: .mmolL)

        guard case let .saved(saved) = result else {
            Issue.record("expected .saved, got \(result)")
            return
        }
        #expect(abs(saved.mgDl - 5.5 * GlucoseConversion.mgDlPerMmolL) <= 1e-9)

        // 1.0 mmol/L = 18.0 mg/dL -> below the 20 mg/dL minimum
        #expect(try await save(value: 1.0, unit: .mmolL) == .invalidValue)
        // 34.0 mmol/L = 612.6 mg/dL -> above the 600 mg/dL maximum
        #expect(try await save(value: 34.0, unit: .mmolL) == .invalidValue)
    }

    /// `SaveGlucoseEntryUseCaseTest.kt:67-82`. It pins `GlucoseConversion`, not the use case: the
    /// glucose editor converts on every unit toggle, so a lossy factor would drift the stored
    /// value each time the segmented control is tapped.
    @Test("unit conversion round trip is lossless")
    func unitConversionRoundTripIsLossless() {
        let original = 123.4
        let roundTrip = GlucoseConversion.toMgDl(
            GlucoseConversion.fromMgDl(original, unit: .mmolL),
            unit: .mmolL
        )
        #expect(abs(roundTrip - original) <= 1e-9)

        let originalMmol = 6.7
        let roundTripMmol = GlucoseConversion.fromMgDl(
            GlucoseConversion.toMgDl(originalMmol, unit: .mmolL),
            unit: .mmolL
        )
        #expect(abs(roundTripMmol - originalMmol) <= 1e-9)
    }

    /// `SaveGlucoseEntryUseCaseTest.kt:84-93`.
    @Test("measurement context and generated id are stored, blank note becomes nil")
    func measurementContextAndGeneratedIdAreStored() async throws {
        let result = try await useCase(
            existingId: nil,
            value: 110.0,
            unit: .mgDl,
            measuredAt: Self.measuredAt,
            timeZone: Self.zone,
            measurementContext: .fasting,
            note: "   "
        )

        guard case let .saved(saved) = result else {
            Issue.record("expected .saved, got \(result)")
            return
        }
        #expect(saved.id == "generated-id")
        #expect(saved.measurementContext == .fasting)
        #expect(saved.note == nil)
        let stored = try #require(repository.currentGlucose().first)
        #expect(repository.currentGlucose().count == 1)
        #expect(stored.mgDl == 110.0)
    }

    /// `SaveGlucoseEntryUseCaseTest.kt:95-105`.
    @Test("existing id is preserved on update")
    func existingIdIsPreservedOnUpdate() async throws {
        _ = try await useCase(
            existingId: "existing",
            value: 100.0,
            unit: .mgDl,
            measuredAt: Self.measuredAt,
            timeZone: Self.zone,
            measurementContext: nil,
            note: nil
        )

        let result = try await useCase(
            existingId: "existing",
            value: 105.0,
            unit: .mgDl,
            measuredAt: Self.measuredAt,
            timeZone: Self.zone,
            measurementContext: nil,
            note: nil
        )

        guard case let .saved(saved) = result else {
            Issue.record("expected .saved, got \(result)")
            return
        }
        #expect(saved.id == "existing")
        let stored = try #require(repository.currentGlucose().first)
        #expect(repository.currentGlucose().count == 1)
        #expect(stored.mgDl == 105.0)
    }

    /// iOS-only, and deliberately not one of the six Kotlin cases: Kotlin's
    /// `mgDl < MIN || mgDl > MAX` is false for NaN, so Android stores a NaN reading where this
    /// rejects it — the same recorded divergence `SaveWeightEntryUseCaseTests.nanIsRejected`
    /// carries (Android backlog §11 A11), reachable because `Double("nan")` is what a text field
    /// produces. NaN survives the conversion in both units, so both are pinned.
    @Test("NaN is rejected")
    func nanIsRejected() async throws {
        #expect(try await save(value: Double.nan) == .invalidValue)
        #expect(try await save(value: Double.nan, unit: .mmolL) == .invalidValue)
        #expect(repository.currentGlucose().isEmpty)
    }
}

extension SaveGlucoseEntryUseCase.Result {
    /// The twin of Kotlin's `assertTrue(result is Result.Saved)`.
    fileprivate var isSaved: Bool {
        if case .saved = self {
            return true
        }
        return false
    }
}
