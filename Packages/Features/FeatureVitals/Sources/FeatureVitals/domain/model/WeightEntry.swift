// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// domain/model/WeightEntry.kt`.

import Foundation

/// One weight measurement, as the feature's domain sees it (`WeightEntry.kt:8-14`).
///
/// `measuredAt` is Kotlin's `Instant`: an absolute point in time, stored as
/// `measured_at_epoch_ms`. The `timeZone` beside it is the zone the reading was *taken* in, kept so
/// the list can redraw "08:14" as it was on the clock that morning rather than as it would be in
/// wherever the phone is now — the same `epochMs + tz_id` pair the schema stores, and the reason
/// `CLAUDE.md` allows `Date` here where a calendar *day* would have to be a `LocalDate`.
///
/// Kotlin's `data class` gives value equality; the `struct` gives it, plus `Sendable` for free.
/// The conformance set is `SalusModel.Profile`'s, for the same reason it is there.
public struct WeightEntry: Equatable, Hashable, Sendable {
    public let id: String
    public let measuredAt: Date
    public let timeZone: TimeZone
    public let kilograms: Double
    public let note: String?

    public init(id: String, measuredAt: Date, timeZone: TimeZone, kilograms: Double, note: String?) {
        self.id = id
        self.measuredAt = measuredAt
        self.timeZone = timeZone
        self.kilograms = kilograms
        self.note = note
    }
}
