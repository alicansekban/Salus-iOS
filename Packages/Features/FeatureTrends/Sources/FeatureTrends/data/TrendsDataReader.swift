// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/data/TrendsDataReader.kt`.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel

/// The only place in this feature that touches Room (`TrendsDataReader.kt:29-65`).
///
/// Everything it returns is a domain type: entities are read, mapped and dropped inside this
/// file, so the analyses that arrive in later tasks physically cannot reach a column. Free-form
/// text is never carried across — not the measurement note, not the intake note, not the
/// medication name, not the profile — because neither output type has a string field it could
/// travel in.
public struct TrendsDataReader: TrendsReader {
    private let vitalsDao: VitalsDao
    private let medicationDao: MedicationDao
    private let profileId: String

    public init(vitalsDao: VitalsDao, medicationDao: MedicationDao, profileId: String) {
        self.vitalsDao = vitalsDao
        self.medicationDao = medicationDao
        self.profileId = profileId
    }

    public func records(days: ClosedRange<Int>, timeZone: TimeZone) async throws -> TrendsRecords {
        let millis = epochMsBoundsOf(days, timeZone: timeZone)
        return try await TrendsRecords(
            measurements: vitalsDao
                .getMeasurementsBetween(
                    profileId: profileId,
                    fromEpochMs: millis.lowerBound,
                    untilEpochMs: millis.upperBound
                )
                .compactMap { $0.toTrendMeasurement(timeZone: timeZone) }
                // The query bounds are instants and the window is local days, so a row can only
                // fall outside on a DST edge — dropping it here keeps the window the analyses
                // claim to cover exactly the one that was asked for.
                .filter { days.contains($0.epochDay) },
            doses: medicationDao
                .getIntakeLogsBetween(profileId: profileId, fromEpochDay: days.lowerBound, toEpochDay: days.upperBound)
                .map { log in
                    TrendDose(
                        epochDay: log.scheduledDateEpochDay,
                        // Only TAKEN counts as taken: PENDING, SKIPPED and MISSED all mean
                        // "not taken" here, and collapsing them at this seam means no
                        // analysis has to know the status vocabulary.
                        //
                        // Note what a PENDING row is, because it decides how the ratio built
                        // on these may be described: snoozing a dose writes one, so a row can
                        // exist without the user having written anything down. The share is
                        // therefore of the doses that were *recorded* — never of the doses the
                        // user logged, and never of the doses a schedule called for. It can
                        // only ever under-state, which is the safe direction.
                        taken: log.status == IntakeStatus.taken.rawValue
                    )
                }
        )
    }
}

/// Inclusive epoch-millisecond window matching `days` in `timeZone`, for the vitals query —
/// measurements are stored as absolute instants while the window is expressed in local days
/// (`TrendsDataReader.kt:72-76`).
///
/// The same arithmetic `HealthStatsAggregator.epochMsBoundsOf` performs; it is repeated here
/// rather than shared because features never depend on `SalusAI`'s internals, and a pure helper
/// this small is worth the module independence it buys.
func epochMsBoundsOf(_ days: ClosedRange<Int>, timeZone: TimeZone) -> ClosedRange<Int64> {
    let from = LocalDateTime(date: LocalDate(epochDay: days.lowerBound), minuteOfDay: 0)
        .instant(in: timeZone)
        .epochMilliseconds
    let untilExclusive = LocalDateTime(date: LocalDate(epochDay: days.upperBound + 1), minuteOfDay: 0)
        .instant(in: timeZone)
        .epochMilliseconds
    return from ... (untilExclusive - 1)
}

extension VitalsMeasurementRecord {
    /// The stored row as a domain measurement, or `nil` when the type column holds a value this
    /// build does not know — an unknown discriminator is dropped rather than guessed at, because
    /// an analysis would otherwise average glucose into weight (`TrendsDataReader.kt:84-97`).
    fileprivate func toTrendMeasurement(timeZone: TimeZone) -> TrendMeasurement? {
        guard let vitalType = VitalType.allCases.first(where: { $0.rawValue == type }) else { return nil }
        let wallClock = Date(epochMilliseconds: measuredAtEpochMs).wallClock(in: timeZone)
        return TrendMeasurement(
            type: vitalType,
            epochDay: wallClock.date.epochDay,
            minuteOfDay: wallClock.minuteOfDay,
            // Values are stored canonically — kg, mmHg, mg/dL — so nothing is converted here.
            primary: valuePrimary,
            secondary: valueSecondary,
            tertiary: valueTertiary
        )
    }
}
