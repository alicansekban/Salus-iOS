// Ported 1:1 from Android
// `core/ai/src/main/kotlin/com/alicansekban/salus/core/ai/HealthStatsAggregator.kt` (the
// `HealthPeriodReader` interface half).

import Foundation

/// The two reads a period-shaped feature needs, behind an interface so consumers never see GRDB.
///
/// It exists for the module boundary rather than for mocking: `HealthStatsAggregator` takes DAO
/// types from `SalusDatabase`, which is an `implementation` dependency here precisely so that
/// database records cannot leak into a feature. Without this seam, a feature that merely wanted to
/// *construct* the aggregator in a test would have to link `SalusDatabase` and the boundary would
/// be gone.
public protocol HealthPeriodReader: Sendable {
    /// The de-identified statistics of the period — the only payload ever sent to the model.
    ///
    /// - Parameters:
    ///   - todayEpochDay: last day of the window, inclusive.
    ///   - timeZone: zone the day boundaries are cut on; a measurement is bucketed by the local
    ///     day it falls on in this zone, not by the zone it was recorded in.
    func aggregate(
        period: SummaryPeriod,
        todayEpochDay: Int,
        timeZone: TimeZone
    ) async throws -> HealthPeriodStats

    /// The period's individual measurements, for a report that prints them as tables.
    ///
    /// Separate from `aggregate` rather than folded into it because the two payloads have
    /// different destinations: statistics go to the model, rows never leave the device. A caller
    /// that needs only one must not pay for — or carry — the other.
    func periodRows(
        period: SummaryPeriod,
        todayEpochDay: Int,
        timeZone: TimeZone
    ) async throws -> HealthPeriodRows
}
