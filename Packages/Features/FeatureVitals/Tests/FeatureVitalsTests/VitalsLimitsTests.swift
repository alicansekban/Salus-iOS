// Ported 1:1 from `feature/vitals/src/test/kotlin/com/alicansekban/salus/feature/vitals/
// domain/usecase/VitalsLimitsTest.kt` — all seven cases, in the Kotlin order, with the Kotlin
// inputs and expectations.
//
// The editors' steppers are bounded by `VitalsLimits` and the save use cases validate against the
// same enum. These tests pin the two together: every endpoint of a published range must be a value
// the matching use case accepts, and a step beyond it must be one it rejects
// (`VitalsLimitsTest.kt:15-22`).

import Foundation
import SalusCommon
import SalusModel
import SalusTesting
import Testing

@testable import FeatureVitals

@Suite("VitalsLimits")
struct VitalsLimitsTests {
    /// `VitalsLimitsTest.kt:32-33`.
    private static let measuredAt = Date(timeIntervalSince1970: 1_750_000_000)
    private static let zone = FixedSalusClock.defaultZone

    /// One unit past a bound: enough to cross it, small enough to stay realistic
    /// (`VitalsLimitsTest.kt:35-36`).
    private static let epsilon = 1.0

    private let repository: FakeVitalsRepository
    private let weight: SaveWeightEntryUseCase
    private let bloodPressure: SaveBloodPressureEntryUseCase
    private let glucose: SaveGlucoseEntryUseCase

    /// `VitalsLimitsTest.kt:26-30`.
    init() {
        let repository = FakeVitalsRepository()
        self.repository = repository
        let idGenerator = FixedIdGenerator(id: "generated-id")
        weight = SaveWeightEntryUseCase(repository: repository, idGenerator: idGenerator)
        bloodPressure = SaveBloodPressureEntryUseCase(repository: repository, idGenerator: idGenerator)
        glucose = SaveGlucoseEntryUseCase(repository: repository, idGenerator: idGenerator)
    }

    /// `VitalsLimitsTest.kt:38-54`.
    @Test("the weight stepper range is exactly what the save accepts")
    func theWeightStepperRangeIsExactlyWhatTheSaveAccepts() async throws {
        let range = VitalsLimits.weightKg

        #expect(try await saveWeight(range.lowerBound) == .saved)
        #expect(try await saveWeight(range.upperBound) == .saved)
        #expect(try await saveWeight(range.lowerBound - Self.epsilon) == .invalidWeight)
        #expect(try await saveWeight(range.upperBound + Self.epsilon) == .invalidWeight)
    }

    /// `VitalsLimitsTest.kt:56-72`.
    @Test("the systolic stepper range is exactly what the save accepts")
    func theSystolicStepperRangeIsExactlyWhatTheSaveAccepts() async throws {
        let range = VitalsLimits.systolicMmHg
        // Diastolic is held below the bound under test so only the systolic check can fire
        // (`VitalsLimitsTest.kt:59-60`).
        let low = VitalsLimits.diastolicMmHg.lowerBound

        #expect(try await saveBloodPressure(range.lowerBound, low) == .saved)
        #expect(try await saveBloodPressure(range.upperBound, low) == .saved)
        #expect(try await saveBloodPressure(range.lowerBound - Self.epsilon, low) == .invalidSystolic)
        #expect(try await saveBloodPressure(range.upperBound + Self.epsilon, low) == .invalidSystolic)
    }

    /// `VitalsLimitsTest.kt:74-90`.
    @Test("the diastolic stepper range is exactly what the save accepts")
    func theDiastolicStepperRangeIsExactlyWhatTheSaveAccepts() async throws {
        let range = VitalsLimits.diastolicMmHg
        // Systolic stays above every diastolic bound, so only the diastolic check can fire
        // (`VitalsLimitsTest.kt:77-78`).
        let high = VitalsLimits.systolicMmHg.upperBound

        #expect(try await saveBloodPressure(high, range.lowerBound) == .saved)
        #expect(try await saveBloodPressure(high, range.upperBound) == .saved)
        #expect(try await saveBloodPressure(high, range.lowerBound - Self.epsilon) == .invalidDiastolic)
        #expect(try await saveBloodPressure(high, range.upperBound + Self.epsilon) == .invalidDiastolic)
    }

    /// `VitalsLimitsTest.kt:92-108`.
    @Test("the pulse stepper range is exactly what the save accepts")
    func thePulseStepperRangeIsExactlyWhatTheSaveAccepts() async throws {
        let range = VitalsLimits.pulseBpm

        #expect(try await saveBloodPressure(120.0, 80.0, pulse: range.lowerBound) == .saved)
        #expect(try await saveBloodPressure(120.0, 80.0, pulse: range.upperBound) == .saved)
        #expect(
            try await saveBloodPressure(120.0, 80.0, pulse: range.lowerBound - Self.epsilon) == .invalidPulse
        )
        #expect(
            try await saveBloodPressure(120.0, 80.0, pulse: range.upperBound + Self.epsilon) == .invalidPulse
        )
    }

    /// `VitalsLimitsTest.kt:110-126`.
    @Test("the mg per dL stepper range is exactly what the save accepts")
    func theMgPerDLStepperRangeIsExactlyWhatTheSaveAccepts() async throws {
        let range = VitalsLimits.glucoseRange(.mgDl)

        #expect(try await saveGlucose(range.lowerBound, .mgDl) == .saved)
        #expect(try await saveGlucose(range.upperBound, .mgDl) == .saved)
        #expect(try await saveGlucose(range.lowerBound - Self.epsilon, .mgDl) == .invalidValue)
        #expect(try await saveGlucose(range.upperBound + Self.epsilon, .mgDl) == .invalidValue)
    }

    /// `VitalsLimitsTest.kt:128-136`.
    @Test("both ends of the mmol per L stepper range survive the conversion to mg per dL")
    func bothEndsOfTheMmolPerLStepperRangeSurviveTheConversionToMgPerDL() async throws {
        let range = VitalsLimits.glucoseRange(.mmolL)

        #expect(try await saveGlucose(range.lowerBound, .mmolL) == .saved)
        #expect(try await saveGlucose(range.upperBound, .mmolL) == .saved)
    }

    /// `VitalsLimitsTest.kt:138-150`.
    @Test("the mmol per L range is the widest one tenth grid that stays inside the mg per dL bounds")
    func theMmolPerLRangeIsTheWidestOneTenthGridInsideTheMgPerDLBounds() {
        let range = VitalsLimits.glucoseRange(.mmolL)
        let mgDl = VitalsLimits.glucoseRange(.mgDl)
        let tenth = 0.1

        // One tenth wider at either end would convert to a value the save rejects, so the range
        // cannot be loosened; that it is not needlessly tight is what these two show
        // (`VitalsLimitsTest.kt:144-145`).
        #expect(GlucoseConversion.toMgDl(range.lowerBound - tenth, unit: .mmolL) < mgDl.lowerBound)
        #expect(GlucoseConversion.toMgDl(range.upperBound + tenth, unit: .mmolL) > mgDl.upperBound)
    }

    // MARK: - Helpers

    /// The three `Saved` payloads carry a generated entry, which none of these cases look at; each
    /// helper answers a payload-free twin so the assertions read as the Kotlin's `is … .Saved` do.
    private enum WeightOutcome: Equatable {
        case saved
        case invalidWeight
    }

    private enum BloodPressureOutcome: Equatable {
        case saved
        case invalidSystolic
        case invalidDiastolic
        case invalidPulse
        case systolicNotAboveDiastolic
    }

    private enum GlucoseOutcome: Equatable {
        case saved
        case invalidValue
    }

    private func saveWeight(_ kilograms: Double) async throws -> WeightOutcome {
        let result = try await weight(
            existingId: nil,
            kilograms: kilograms,
            measuredAt: Self.measuredAt,
            timeZone: Self.zone,
            note: nil
        )
        switch result {
        case .saved: return .saved
        case .invalidWeight: return .invalidWeight
        }
    }

    /// `VitalsLimitsTest.kt:152-153`.
    private func saveBloodPressure(
        _ systolic: Double,
        _ diastolic: Double,
        pulse: Double? = nil
    ) async throws -> BloodPressureOutcome {
        let result = try await bloodPressure(
            existingId: nil,
            systolic: systolic,
            diastolic: diastolic,
            pulse: pulse,
            measuredAt: Self.measuredAt,
            timeZone: Self.zone,
            note: nil
        )
        switch result {
        case .saved: return .saved
        case .invalidSystolic: return .invalidSystolic
        case .invalidDiastolic: return .invalidDiastolic
        case .invalidPulse: return .invalidPulse
        case .systolicNotAboveDiastolic: return .systolicNotAboveDiastolic
        }
    }

    /// `VitalsLimitsTest.kt:155-156`.
    private func saveGlucose(_ value: Double, _ unit: GlucoseUnit) async throws -> GlucoseOutcome {
        let result = try await glucose(
            existingId: nil,
            value: value,
            unit: unit,
            measuredAt: Self.measuredAt,
            timeZone: Self.zone,
            measurementContext: nil,
            note: nil
        )
        switch result {
        case .saved: return .saved
        case .invalidValue: return .invalidValue
        }
    }
}
