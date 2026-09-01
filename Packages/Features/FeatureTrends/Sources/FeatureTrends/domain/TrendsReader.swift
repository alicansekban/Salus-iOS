// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/domain/TrendsReader.kt`.

import Foundation

/// The single read the trends screen needs, behind an interface so no consumer ever sees Room
/// (`TrendsReader.kt:14-24`).
///
/// It exists for the module boundary rather than for mocking, the same way `HealthPeriodReader`
/// does in `:core:ai`: the implementation takes DAO types from `SalusDatabase`, and this seam is
/// what keeps Room entities out of the analyses.
public protocol TrendsReader: Sendable {
    /// Every record of the window, mapped onto the note-free domain types (`TrendsReader.kt:16-22`).
    ///
    /// - Parameters:
    ///   - days: inclusive local-day window, ending on the day the caller calls today.
    ///   - timeZone: zone the day boundaries are cut on; a measurement is bucketed by the local
    ///     day it falls on in this zone, not by the zone it happened to be recorded in.
    func records(days: ClosedRange<Int>, timeZone: TimeZone) async throws -> TrendsRecords
}
