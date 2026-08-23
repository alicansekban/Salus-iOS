// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// data/WeightEntryMapper.kt`.
//
// The Kotlin functions and the unit constant are `internal`; so are these, which is the same reach
// — a Swift module is the unit Gradle calls a module. This file is the only place a
// `VitalsMeasurementRecord` becomes a `WeightEntry`, which is what keeps `SalusDatabase`'s records
// inside the repository as `CLAUDE.md` requires.

import Foundation
import SalusDatabase
import SalusModel

/// `WeightEntryMapper.kt:10`. Stored in `vitals_measurements.unit` and read back by the other
/// platform out of a backup archive, so it is a persisted string: never "improve" it.
let weightUnit = "kg"

/// `WeightEntryMapper.kt:13-19`.
extension VitalsMeasurementRecord {
    func toWeightEntry() -> WeightEntry {
        WeightEntry(
            id: id,
            measuredAt: Date(epochMilliseconds: measuredAtEpochMs),
            // Kotlin's `TimeZone.of` throws on an identifier the platform does not know — a zone
            // retired from the database, or one written by a build with a newer tzdb. Degrading to
            // GMT is the same call `ProfileMappers` makes for an unknown `sex`: one unreadable row
            // must not take the whole history list down with it. Only the displayed wall-clock
            // time is affected; the instant itself is the column, and it is exact.
            timeZone: TimeZone(identifier: timeZoneId) ?? .gmt,
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
