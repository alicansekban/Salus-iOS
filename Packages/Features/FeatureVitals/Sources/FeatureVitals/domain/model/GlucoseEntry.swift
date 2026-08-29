// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// domain/model/GlucoseEntry.kt`.

import Foundation
import SalusModel

/// One blood-glucose measurement, as the feature's domain sees it (`GlucoseEntry.kt:8-15`).
///
/// The `measuredAt` + `timeZone` pair is `WeightEntry`'s, for the reason spelled out there.
///
/// **`mgDl` is the canonical storage value, always.** `GlucoseUnit` is a *display* choice: a
/// reading typed in mmol/L is converted once, on the way in, so the same measurement is one number
/// no matter which unit the user had selected when it was recorded — and so a unit toggle can
/// never rewrite history. `GlucoseConversion` is the only place the two forms meet.
public struct GlucoseEntry: Equatable, Hashable, Sendable {
    public let id: String
    public let measuredAt: Date
    public let timeZone: TimeZone
    public let mgDl: Double
    public let measurementContext: MeasurementContext?
    public let note: String?

    public init(
        id: String,
        measuredAt: Date,
        timeZone: TimeZone,
        mgDl: Double,
        measurementContext: MeasurementContext?,
        note: String?
    ) {
        self.id = id
        self.measuredAt = measuredAt
        self.timeZone = timeZone
        self.mgDl = mgDl
        self.measurementContext = measurementContext
        self.note = note
    }
}
