// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// data/BloodPressureEntryMapper.kt`.
//
// Module-internal like the Kotlin, and the only place a `VitalsMeasurementRecord` becomes a
// `BloodPressureEntry` — `WeightEntryMapper.swift`'s note on why that matters applies unchanged.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel

/// `BloodPressureEntryMapper.kt:10`. Stored in `vitals_measurements.unit` and read back by the
/// other platform out of a backup archive, so it is a persisted string: never "improve" it.
let bloodPressureUnit = "mmHg"

/// `BloodPressureEntryMapper.kt:13` — the fallback keeps the mapper total. The DAO always returns
/// a secondary value for this type, so this is the value a row that should not exist maps to
/// rather than a reading anyone will see.
private let missingDiastolic = 0.0

/// `BloodPressureEntryMapper.kt:16-24`.
extension VitalsMeasurementRecord {
    /// - Throws: `IllegalTimeZoneError.unknownTimeZone` when `tz_id` names a zone this platform
    ///   cannot resolve, which is what `TimeZone.of` does at `BloodPressureEntryMapper.kt:19`.
    ///   `WeightEntryMapper.swift` reasons out why degrading to GMT would be quieter and wrong.
    func toBloodPressureEntry() throws -> BloodPressureEntry {
        guard let timeZone = TimeZone(identifier: timeZoneId) else {
            throw IllegalTimeZoneError.unknownTimeZone(timeZoneId)
        }
        return BloodPressureEntry(
            id: id,
            measuredAt: Date(epochMilliseconds: measuredAtEpochMs),
            timeZone: timeZone,
            systolic: valuePrimary,
            diastolic: valueSecondary ?? missingDiastolic,
            pulse: valueTertiary,
            note: note
        )
    }
}

/// `BloodPressureEntryMapper.kt:27-39`.
extension BloodPressureEntry {
    func toRecord(profileId: String) -> VitalsMeasurementRecord {
        VitalsMeasurementRecord(
            id: id,
            profileId: profileId,
            type: VitalType.bloodPressure.rawValue,
            measuredAtEpochMs: measuredAt.epochMilliseconds,
            timeZoneId: timeZone.identifier,
            valuePrimary: systolic,
            valueSecondary: diastolic,
            valueTertiary: pulse,
            unit: bloodPressureUnit,
            // Blood pressure fills all three value columns; the measurement context belongs to
            // glucose, which shares this table.
            measurementContext: nil,
            note: note
        )
    }
}
