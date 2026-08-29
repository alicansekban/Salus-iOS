// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// domain/model/BloodPressureEntry.kt`.

import Foundation

/// One blood-pressure measurement, as the feature's domain sees it
/// (`BloodPressureEntry.kt:8-16`).
///
/// The `measuredAt` + `timeZone` pair is `WeightEntry`'s, for the reason spelled out there: the
/// zone is what redraws the reading at the wall-clock time it was taken at.
///
/// **`systolic`, `diastolic` and `pulse` are `Double` although the UI renders whole numbers.** That
/// is the Kotlin type and it is not a translation slip: the three share one table with weight and
/// glucose (`value_primary`, `value_secondary`, `value_tertiary` are all `REAL`), so a narrower
/// type here would have to widen again at the mapper and would round on the way.
///
/// `pulse` is optional because a cuff that does not measure it is a normal cuff, and `nil` is what
/// the tertiary column then holds — never zero.
public struct BloodPressureEntry: Equatable, Hashable, Sendable {
    public let id: String
    public let measuredAt: Date
    public let timeZone: TimeZone
    public let systolic: Double
    public let diastolic: Double
    public let pulse: Double?
    public let note: String?

    public init(
        id: String,
        measuredAt: Date,
        timeZone: TimeZone,
        systolic: Double,
        diastolic: Double,
        pulse: Double?,
        note: String?
    ) {
        self.id = id
        self.measuredAt = measuredAt
        self.timeZone = timeZone
        self.systolic = systolic
        self.diastolic = diastolic
        self.pulse = pulse
        self.note = note
    }
}
