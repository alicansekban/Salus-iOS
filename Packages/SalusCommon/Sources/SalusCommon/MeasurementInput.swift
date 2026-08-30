// Ported 1:1 from Android
// `core/common/src/main/kotlin/com/alicansekban/salus/core/common/MeasurementInput.kt`.

/// Parsing and range rules for the numeric measurement fields (onboarding and the profile
/// editor). Pure Swift: the same rules have to hold as the Android port, and they are the only
/// place that decides whether a typed value is worth writing.
///
/// A blank field is not an error — every measurement field is optional — so callers treat
/// "blank" and "invalid" differently.
public enum MeasurementInput {
    // `MeasurementInput.kt:13` — `MIN_HEIGHT_CM`.
    public static let minHeightCm = 50.0

    // `MeasurementInput.kt:14` — `MAX_HEIGHT_CM`.
    public static let maxHeightCm = 250.0

    // Matches SaveWeightEntryUseCase, which rejects anything outside this range anyway.
    // `MeasurementInput.kt:17` — `MIN_WEIGHT_KG`.
    public static let minWeightKg = 20.0

    // `MeasurementInput.kt:18` — `MAX_WEIGHT_KG`.
    public static let maxWeightKg = 400.0

    /// `MeasurementInput.kt:20`.
    public static func parseHeightCm(_ text: String) -> Double? {
        parse(text, min: minHeightCm, max: maxHeightCm)
    }

    /// `MeasurementInput.kt:22`.
    public static func parseWeightKg(_ text: String) -> Double? {
        parse(text, min: minWeightKg, max: maxWeightKg)
    }

    /// Accepts both decimal separators: Turkish keyboards produce a comma.
    /// `MeasurementInput.kt:25-26` — `text.trim().replace(',', '.').toDoubleOrNull()
    /// ?.takeIf { it in min..max }`. The comma replace is already in the Android source, so the
    /// iOS port matches 1:1, including it.
    private static func parse(_ text: String, min: Double, max: Double) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return (min ... max).contains(value) ? value : nil
    }
}
