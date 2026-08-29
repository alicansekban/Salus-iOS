// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// data/GlucoseEntryMapper.kt`.
//
// Module-internal like the Kotlin, and the only place a `VitalsMeasurementRecord` becomes a
// `GlucoseEntry` — `WeightEntryMapper.swift`'s note on why that matters applies unchanged.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel

/// `GlucoseEntryMapper.kt:11`. Storage is always mg/dL whatever unit the user reads in, and this
/// string is what the other platform reads back out of a backup archive: never "improve" it.
let glucoseStorageUnit = "mg/dL"

/// `GlucoseEntryMapper.kt:14-23`.
extension VitalsMeasurementRecord {
    /// - Throws: `IllegalTimeZoneError.unknownTimeZone` when `tz_id` names a zone this platform
    ///   cannot resolve, which is what `TimeZone.of` does at `GlucoseEntryMapper.kt:17`.
    ///
    ///   A stored `measurement_context` this build does not know is a different matter and does
    ///   **not** throw: Kotlin's `MeasurementContext.entries.firstOrNull { it.name == stored }`
    ///   answers null, and `MeasurementContext(rawValue:)` answers nil for the same input. Losing
    ///   a label an older or newer build wrote costs a caption; refusing the row would hide the
    ///   reading itself.
    func toGlucoseEntry() throws -> GlucoseEntry {
        guard let timeZone = TimeZone(identifier: timeZoneId) else {
            throw IllegalTimeZoneError.unknownTimeZone(timeZoneId)
        }
        return GlucoseEntry(
            id: id,
            measuredAt: Date(epochMilliseconds: measuredAtEpochMs),
            timeZone: timeZone,
            mgDl: valuePrimary,
            measurementContext: measurementContext.flatMap(MeasurementContext.init(rawValue:)),
            note: note
        )
    }
}

/// `GlucoseEntryMapper.kt:26-38`.
extension GlucoseEntry {
    func toRecord(profileId: String) -> VitalsMeasurementRecord {
        VitalsMeasurementRecord(
            id: id,
            profileId: profileId,
            type: VitalType.bloodGlucose.rawValue,
            measuredAtEpochMs: measuredAt.epochMilliseconds,
            timeZoneId: timeZone.identifier,
            valuePrimary: mgDl,
            // Glucose fills one value column; the other two belong to blood pressure, which shares
            // this table.
            valueSecondary: nil,
            valueTertiary: nil,
            unit: glucoseStorageUnit,
            measurementContext: measurementContext?.rawValue,
            note: note
        )
    }
}
