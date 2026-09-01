// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/MetricDisplay.kt`.

import Foundation
import SalusModel

/// The one place a stored number becomes a number the user reads (`MetricDisplay.kt:8-18`).
///
/// Everything behind the screen is canonical: the reader, the analyses and `TrendsData` all carry
/// glucose in mg/dL, because normalizing and averaging must not depend on a display setting.
/// That makes this conversion the last step before a value is written down, and the only step —
/// a value converted anywhere else would be converted twice.
///
/// Kept as plain functions outside the views so the arithmetic and the decimal places are
/// covered by unit tests rather than by looking at a device, the same way the chart mappings are.
enum MetricDisplay {
    /// A stored value in the unit it is shown in. Only glucose has a unit the user can change
    /// (`MetricDisplay.kt:22-25`).
    static func value(type: VitalType, stored: Double, glucoseUnit: GlucoseUnit) -> Double {
        switch type {
        case .bloodGlucose: GlucoseConversion.fromMgDl(stored, unit: glucoseUnit)
        case .bloodPressure, .weight: stored
        }
    }

    /// How many decimals a metric is written with, in the unit it is being shown in
    /// (`MetricDisplay.kt:34-41`).
    ///
    /// Matches the vitals screen exactly, so the same reading reads the same on both: whole
    /// numbers for mmHg and mg/dL, one decimal for kilograms and for mmol/L — a tenth is a real
    /// difference on a scale and in mmol/L, and noise in the other two.
    static func decimals(type: VitalType, glucoseUnit: GlucoseUnit) -> Int {
        switch type {
        case .weight: decimal
        case .bloodPressure: whole
        case .bloodGlucose:
            switch glucoseUnit {
            case .mgDl: whole
            case .mmolL: decimal
            }
        }
    }

    /// Writes an *already converted* value with `decimals` decimals (`MetricDisplay.kt:54-55`).
    ///
    /// Separate from `format` because some call sites read their numbers back off the chart they
    /// drew, where the conversion has already happened. Converting again there would be the one
    /// mistake this file exists to prevent, so the step that converts and the step that writes
    /// are two named functions rather than one that has to be used carefully.
    ///
    /// Formatted through `locale` rather than by concatenation, so the digits and the decimal
    /// separator follow the reader the way the string resources do. Defaults to the current
    /// locale, the twin of Android's `LocalLocale.current.platformLocale`.
    static func write(converted: Double, decimals: Int, locale: Locale = .current) -> String {
        String(format: "%.\(decimals)f", locale: locale, converted)
    }

    /// A stored value, converted and written out: `value` then `write`, in one step
    /// (`MetricDisplay.kt:58-67`).
    static func format(
        type: VitalType,
        stored: Double,
        glucoseUnit: GlucoseUnit,
        locale: Locale = .current
    ) -> String {
        write(
            converted: value(type: type, stored: stored, glucoseUnit: glucoseUnit),
            decimals: decimals(type: type, glucoseUnit: glucoseUnit),
            locale: locale
        )
    }

    private static let whole = 0
    private static let decimal = 1
}
