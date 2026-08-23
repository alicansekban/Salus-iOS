// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// data/WeightEntryMapper.kt`.
//
// The Kotlin functions and the unit constant are `internal`; so are these, which is the same reach
// — a Swift module is the unit Gradle calls a module. This file is the only place a
// `VitalsMeasurementRecord` becomes a `WeightEntry`, which is what keeps `SalusDatabase`'s records
// inside the repository as `CLAUDE.md` requires.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel

/// `WeightEntryMapper.kt:10`. Stored in `vitals_measurements.unit` and read back by the other
/// platform out of a backup archive, so it is a persisted string: never "improve" it.
let weightUnit = "kg"

/// `WeightEntryMapper.kt:13-19`.
extension VitalsMeasurementRecord {
    /// - Throws: `IllegalTimeZoneError.unknownTimeZone` when `tz_id` names a zone this platform
    ///   cannot resolve, which is what `TimeZone.of` does at `WeightEntryMapper.kt:16`. Degrading
    ///   to GMT instead would be quieter and wrong: the zone is what redraws the reading at the
    ///   wall-clock time it was taken at, so a silent substitution moves a measurement to another
    ///   hour of the day and nothing says so. The repository's streams finish with this error, the
    ///   way a Kotlin `Flow.map` that throws does.
    ///
    ///   Recorded, not fixed here: Foundation's `TimeZone(identifier:)` rejects the fixed-offset
    ///   spellings (`"+03:00"`, `"UTC+03:00"`) that `kotlinx.datetime.TimeZone.of` accepts, so a
    ///   row written by Android with an offset id would throw on iOS where Android reads it back.
    ///   Nothing in the app writes one today — every writer stores a region id — but a backup from
    ///   a future Android build could.
    func toWeightEntry() throws -> WeightEntry {
        guard let timeZone = TimeZone(identifier: timeZoneId) else {
            throw IllegalTimeZoneError.unknownTimeZone(timeZoneId)
        }
        return WeightEntry(
            id: id,
            measuredAt: Date(epochMilliseconds: measuredAtEpochMs),
            timeZone: timeZone,
            kilograms: valuePrimary,
            note: note
        )
    }
}

/// `WeightEntryMapper.kt:22-33`.
extension WeightEntry {
    func toRecord(profileId: String) -> VitalsMeasurementRecord {
        VitalsMeasurementRecord(
            id: id,
            profileId: profileId,
            type: VitalType.weight.rawValue,
            measuredAtEpochMs: measuredAt.epochMilliseconds,
            timeZoneId: timeZone.identifier,
            valuePrimary: kilograms,
            // Weight fills one value column. The other two, and the measurement context, belong to
            // blood pressure and glucose, which share this table.
            valueSecondary: nil,
            valueTertiary: nil,
            unit: weightUnit,
            measurementContext: nil,
            note: note
        )
    }
}
