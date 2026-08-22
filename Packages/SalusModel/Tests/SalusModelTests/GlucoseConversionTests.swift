import Testing

@testable import SalusModel

// Pins the mg/dL ↔ mmol/L conversion (`GlucoseConversion.kt:11-24`).
//
// The factor is health data, not a display nicety: two features converting one reading with two
// different factors would show two different numbers for the same measurement. So the constant is
// asserted literally, and the two directions are asserted to undo each other.

/// The tolerance Android's own numeric tests use (`MetricStatsTest.kt:74`).
private let tolerance = 1e-9

@Suite("GlucoseConversion (GlucoseConversion.kt)")
struct GlucoseConversionTests {
    @Test("the factor is the Kotlin constant, digit for digit")
    func factor() {
        // GlucoseConversion.kt:13
        #expect(GlucoseConversion.mgDlPerMmolL == 18.0182)
    }

    @Test("mg/dL is the storage unit, so converting it is the identity", arguments: [0.0, 72.0, 99.1001, 350.5])
    func mgDlIsTheIdentity(_ value: Double) {
        // GlucoseConversion.kt:16 / :21
        #expect(GlucoseConversion.toMgDl(value, unit: .mgDl) == value)
        #expect(GlucoseConversion.fromMgDl(value, unit: .mgDl) == value)
    }

    @Test("mmol/L multiplies into mg/dL")
    func toMgDlFromMmolL() {
        // GlucoseConversion.kt:17 — 5.5 mmol/L is 5.5 * 18.0182 mg/dL.
        #expect(abs(GlucoseConversion.toMgDl(5.5, unit: .mmolL) - 99.1001) < tolerance)
        #expect(abs(GlucoseConversion.toMgDl(1.0, unit: .mmolL) - 18.0182) < tolerance)
        #expect(GlucoseConversion.toMgDl(0.0, unit: .mmolL) == 0.0)
    }

    @Test("mg/dL divides back into mmol/L")
    func fromMgDlToMmolL() {
        // GlucoseConversion.kt:22
        #expect(abs(GlucoseConversion.fromMgDl(99.1001, unit: .mmolL) - 5.5) < tolerance)
        #expect(abs(GlucoseConversion.fromMgDl(18.0182, unit: .mmolL) - 1.0) < tolerance)
        #expect(GlucoseConversion.fromMgDl(0.0, unit: .mmolL) == 0.0)
    }

    @Test(
        "the two directions undo each other, for both units",
        arguments: [0.0, 1.0, 5.5, 72.4, 99.1001, 126.0, 350.5], GlucoseUnit.allCases
    )
    func roundTrip(_ value: Double, _ unit: GlucoseUnit) {
        let storedThenDisplayed = GlucoseConversion.fromMgDl(GlucoseConversion.toMgDl(value, unit: unit), unit: unit)
        #expect(abs(storedThenDisplayed - value) < tolerance, "\(value) via \(unit.rawValue)")

        let displayedThenStored = GlucoseConversion.toMgDl(GlucoseConversion.fromMgDl(value, unit: unit), unit: unit)
        #expect(abs(displayedThenStored - value) < tolerance, "\(value) via \(unit.rawValue)")
    }
}
