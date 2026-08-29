// Ported 1:1 from Android
// `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/domain/model/CyclePrediction.kt`.

/// How much the predictor trusts what it computed (`CyclePrediction.kt:5-9`).
///
/// Raw values are the Kotlin constant names. A prediction is NEVER persisted — it is always
/// derived from the recorded periods — so nothing reads these values back off disk; they are
/// Android's so the two enums stay one type with one spelling.
public enum CycleConfidence: String, CaseIterable, Sendable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
}
