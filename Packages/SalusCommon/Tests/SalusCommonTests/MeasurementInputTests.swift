// Pins the parse rules and the inclusive bounds in `MeasurementInput.swift`, against Kotlin's
// `core/common/src/main/kotlin/com/alicansekban/salus/core/common/MeasurementInput.kt`.
//
// Android has no test file for `MeasurementInput`; its bounds are pinned by the onboarding and
// profile tests instead. iOS writes its own table here so the rules are load-bearing on both
// platforms. The comma→dot replace is already in the Kotlin source (`MeasurementInput.kt:25`), so
// the comma case is a port verbatim, not an iOS-only divergence.

import Testing

@testable import SalusCommon

@Suite("MeasurementInput.parseHeightCm")
struct MeasurementInputHeightTests {
    @Test("a blank field is nil, never an error")
    func blankIsNil() {
        #expect(MeasurementInput.parseHeightCm("") == nil)
    }

    @Test("a whole number in range is parsed")
    func wholeInRange() {
        #expect(MeasurementInput.parseHeightCm("170") == 170.0)
    }

    @Test("a decimal in range is parsed")
    func decimalInRange() {
        #expect(MeasurementInput.parseHeightCm("170.5") == 170.5)
    }

    @Test("a value below the minimum is nil")
    func belowMinIsNil() {
        #expect(MeasurementInput.parseHeightCm("49") == nil)
    }

    @Test("a value above the maximum is nil")
    func aboveMaxIsNil() {
        #expect(MeasurementInput.parseHeightCm("251") == nil)
    }

    @Test("a value far above the maximum is nil")
    func farAboveMaxIsNil() {
        #expect(MeasurementInput.parseHeightCm("300") == nil)
    }

    @Test("a Turkish decimal comma is treated as a decimal point")
    func turkishCommaIsAccepted() {
        #expect(MeasurementInput.parseHeightCm("72,4") == 72.4)
    }

    @Test("non-numeric text is nil")
    func nonNumericIsNil() {
        #expect(MeasurementInput.parseHeightCm("abc") == nil)
    }

    @Test("a field of only spaces is nil")
    func onlySpacesIsNil() {
        #expect(MeasurementInput.parseHeightCm("  ") == nil)
    }
}

@Suite("MeasurementInput.parseWeightKg")
struct MeasurementInputWeightTests {
    @Test("the inclusive lower bound passes")
    func lowerBoundIsInclusive() {
        #expect(MeasurementInput.parseWeightKg("20") == 20.0)
    }

    @Test("the inclusive upper bound passes")
    func upperBoundIsInclusive() {
        #expect(MeasurementInput.parseWeightKg("400") == 400.0)
    }

    @Test("a value just below the minimum is nil")
    func justBelowMinIsNil() {
        #expect(MeasurementInput.parseWeightKg("19.9") == nil)
    }

    @Test("a value just above the maximum is nil")
    func justAboveMaxIsNil() {
        #expect(MeasurementInput.parseWeightKg("400.1") == nil)
    }

    @Test("a blank field is nil, never an error")
    func blankIsNil() {
        #expect(MeasurementInput.parseWeightKg("") == nil)
    }

    @Test("non-numeric text is nil")
    func nonNumericIsNil() {
        #expect(MeasurementInput.parseWeightKg("abc") == nil)
    }
}
