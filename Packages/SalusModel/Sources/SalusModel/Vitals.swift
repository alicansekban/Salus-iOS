// Ported 1:1 from Android
// `core/model/src/main/kotlin/com/alicansekban/salus/core/model/Vitals.kt`.

/// Which measurement a vitals row holds.
///
/// Raw values are the Kotlin constant names (`Vitals.kt:3-7`), which is what is persisted.
public enum VitalType: String, CaseIterable, Equatable, Hashable, Sendable {
    case weight = "WEIGHT"
    case bloodPressure = "BLOOD_PRESSURE"
    case bloodGlucose = "BLOOD_GLUCOSE"
}

/// When, relative to eating and sleeping, a reading was taken.
///
/// Raw values are the Kotlin constant names (`Vitals.kt:9-14`).
public enum MeasurementContext: String, CaseIterable, Equatable, Hashable, Sendable {
    case fasting = "FASTING"
    case postMeal = "POST_MEAL"
    case bedtime = "BEDTIME"
    case random = "RANDOM"
}

/// The unit blood glucose is *displayed* in. Storage is always mg/dL; `GlucoseConversion` is the
/// only place the two are converted.
///
/// Raw values are the Kotlin constant names (`Vitals.kt:16-19`), persisted under the
/// `glucose_unit` preference key.
public enum GlucoseUnit: String, CaseIterable, Equatable, Hashable, Sendable {
    case mgDl = "MG_DL"
    case mmolL = "MMOL_L"

    /// `UserSettings.glucoseUnit`'s default (`Settings.kt:23`).
    public static let `default`: GlucoseUnit = .mgDl

    /// Decodes a persisted string the way Android's `toEnumOrDefault` does
    /// (`SalusPreferencesDataSource.kt:89-90`): an exact, case-sensitive constant-name match,
    /// and anything else — including a missing value — falls back to the default.
    public static func fromStoredValue(_ stored: String?) -> GlucoseUnit {
        guard let stored, let unit = GlucoseUnit(rawValue: stored) else { return .default }
        return unit
    }
}
