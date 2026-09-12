// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// domain/usecase/VitalsLimits.kt`.
//
// Kotlin's `internal object` is a caseless Swift `enum`, the shape this port uses everywhere for a
// namespace that is never instantiated. `ClosedFloatingPointRange<Double>` is `ClosedRange<Double>`,
// and `x !in range` is `!range.contains(x)` — the save use cases below read it that way.
//
// The bounds themselves moved here from the three `Save…EntryUseCase` types, which each used to
// state their own pair of constants. That is exactly the drift this file exists to remove: a
// stepper bounded by one number and a save validating against another is an input that offers a
// value its own save refuses.

import Foundation
import SalusModel

/// The one place a vitals reading's accepted span is written down (`VitalsLimits.kt:8-17`).
///
/// The save use cases validate against it and the editors bound their steppers by it, so the input
/// can never offer a value the save refuses, nor hide one it would have accepted. Stating a bound
/// twice is exactly the drift this enum exists to remove.
///
/// Pure Swift, no SwiftUI: it sits in `domain` with the use cases that read it.
enum VitalsLimits {
    /// `VitalsLimits.kt:19`.
    static let weightKg: ClosedRange<Double> = 20.0 ... 400.0

    /// `VitalsLimits.kt:21`.
    static let systolicMmHg: ClosedRange<Double> = 60.0 ... 250.0

    /// `VitalsLimits.kt:23`.
    static let diastolicMmHg: ClosedRange<Double> = 30.0 ... 150.0

    /// `VitalsLimits.kt:25`.
    static let pulseBpm: ClosedRange<Double> = 20.0 ... 250.0

    /// Canonical storage bounds; every other unit is derived from these (`VitalsLimits.kt:27-28`).
    static let glucoseMgDl: ClosedRange<Double> = 20.0 ... 600.0

    /// The span a glucose stepper may offer in `unit` (`VitalsLimits.kt:30-45`).
    ///
    /// mmol/L is derived rather than restated, and rounded **inwards** on the 0.1 grid the stepper
    /// moves on — up at the floor, down at the ceiling. Rounding outwards would put a reachable
    /// endpoint outside ``glucoseMgDl`` once converted, which is the save refusing a value its own
    /// input offered.
    static func glucoseRange(_ unit: GlucoseUnit) -> ClosedRange<Double> {
        switch unit {
        case .mgDl:
            return glucoseMgDl

        case .mmolL:
            let low = GlucoseConversion.fromMgDl(glucoseMgDl.lowerBound, unit: unit)
            let high = GlucoseConversion.fromMgDl(glucoseMgDl.upperBound, unit: unit)
            return ((low * tenths).rounded(.up) / tenths) ... ((high * tenths).rounded(.down) / tenths)
        }
    }

    /// The stepper's grid for mmol/L: one decimal (`VitalsLimits.kt:47-48`).
    private static let tenths = 10.0
}
