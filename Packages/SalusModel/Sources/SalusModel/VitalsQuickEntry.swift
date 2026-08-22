// Ported 1:1 from Android
// `core/model/src/main/kotlin/com/alicansekban/salus/core/model/VitalsQuickEntry.kt`.

/// Cross-feature contract for writing a vitals measurement without importing the feature that
/// owns it. Implemented by `FeatureVitals`, consumed by `FeatureOnboarding` so the weight asked
/// for at first launch becomes the first point of the weight chart instead of a second,
/// profile-level copy of the same number. Mirrors `DoseActions`.
public protocol VitalsQuickEntry: Sendable {
    /// Records a weight measurement. Out-of-range values are rejected by the same rules the
    /// weight editor uses, in which case nothing is written and this returns false.
    ///
    /// - Parameter epochMs: Kotlin's `Long`, so `Int64` rather than `Int`.
    func recordWeight(kilograms: Double, epochMs: Int64, timeZoneId: String) async throws -> Bool
}
