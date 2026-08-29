// Ported 1:1 from Android
// `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/domain/model/CyclePrediction.kt`.

import SalusModel

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

/// Computed cycle prediction. NEVER persisted — always derived from recorded periods by
/// ``CyclePredictor`` (`CyclePrediction.kt:15-23`).
public struct CyclePrediction: Equatable, Sendable {
    public let nextPeriodStart: LocalDate
    public let fertileWindowStart: LocalDate
    public let fertileWindowEnd: LocalDate
    public let ovulationDate: LocalDate
    public let averageCycleLength: Int
    public let confidence: CycleConfidence
    public let isIrregular: Bool

    public init(
        nextPeriodStart: LocalDate,
        fertileWindowStart: LocalDate,
        fertileWindowEnd: LocalDate,
        ovulationDate: LocalDate,
        averageCycleLength: Int,
        confidence: CycleConfidence,
        isIrregular: Bool
    ) {
        self.nextPeriodStart = nextPeriodStart
        self.fertileWindowStart = fertileWindowStart
        self.fertileWindowEnd = fertileWindowEnd
        self.ovulationDate = ovulationDate
        self.averageCycleLength = averageCycleLength
        self.confidence = confidence
        self.isIrregular = isIrregular
    }
}
