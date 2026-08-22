// Ported 1:1 from Android
// `core/model/src/main/kotlin/com/alicansekban/salus/core/model/GlucoseConversion.kt`.

/// Unit conversion between the canonical mg/dL storage value and the display unit.
///
/// Lives beside `GlucoseUnit` rather than inside a feature because more than one feature has to
/// show the same reading: a value converted with a different factor in a different screen would
/// be two different numbers for one measurement, on health data.
public enum GlucoseConversion {
    /// `GlucoseConversion.kt:13` — `MG_DL_PER_MMOL_L`.
    public static let mgDlPerMmolL = 18.0182

    /// Converts a value shown in `unit` into the mg/dL that gets stored (`GlucoseConversion.kt:15-18`).
    public static func toMgDl(_ value: Double, unit: GlucoseUnit) -> Double {
        switch unit {
        case .mgDl: value
        case .mmolL: value * mgDlPerMmolL
        }
    }

    /// Converts a stored mg/dL value into the display `unit` (`GlucoseConversion.kt:20-23`).
    public static func fromMgDl(_ mgDl: Double, unit: GlucoseUnit) -> Double {
        switch unit {
        case .mgDl: mgDl
        case .mmolL: mgDl / mgDlPerMmolL
        }
    }
}
