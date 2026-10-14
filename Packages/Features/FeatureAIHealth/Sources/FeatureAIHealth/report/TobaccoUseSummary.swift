// Twin of Android `feature/aihealth/.../report/TobaccoUseSummary.kt`.

import Foundation
import SalusCommon
import SalusSmoking

/// What the report's "Tobacco use" section states, as numbers. Money is not a field: the section
/// is for a doctor, the snapshot it is read from carries saved amounts and craving counts, and
/// neither is the doctor's business (spec section 7 - "no money, no craving data").
///
/// Only the fields of the person's `mode` are set: a quit attempt has a date, a duration and
/// slips, a reduction has a daily average. A field that does not apply is `nil`, never a zero.
///
/// - `quitDateEpochDay`: the local day the current quit attempt started.
/// - `durationDays`: whole days since the attempt started.
/// - `slipCount`: slips inside the current attempt.
/// - `dailyAverageTenths`: average units per day over the logged days of the last seven, in tenths
///   so the number is formatted without a locale; `nil` when no day has an entry.
public struct TobaccoUseSummary: Equatable, Sendable {
    public let mode: SmokingMode
    public let quitDateEpochDay: Int?
    public let durationDays: Int?
    public let slipCount: Int?
    public let dailyAverageTenths: Int?

    public init(
        mode: SmokingMode,
        quitDateEpochDay: Int? = nil,
        durationDays: Int? = nil,
        slipCount: Int? = nil,
        dailyAverageTenths: Int? = nil
    ) {
        self.mode = mode
        self.quitDateEpochDay = quitDateEpochDay
        self.durationDays = durationDays
        self.slipCount = slipCount
        self.dailyAverageTenths = dailyAverageTenths
    }
}

/// Reads the report's figures off a snapshot, or `nil` when nothing is set up (no section at all).
///
/// The quit date is the attempt's start cut on `zone` - the device's local day, the same rule the
/// rest of the report uses for dates - not the zone the attempt was logged in.
func tobaccoUseSummaryOf(_ snapshot: SmokingSnapshot, zone: TimeZone) -> TobaccoUseSummary? {
    switch snapshot {
    case .notSetUp:
        nil

    case let .quit(quit):
        TobaccoUseSummary(
            mode: .quit,
            quitDateEpochDay: Int(epochDay(of: quit.attemptStartedAtMs, in: zone)),
            durationDays: Int(quit.attemptElapsedMs / msPerDay),
            slipCount: quit.slipCount
        )

    case let .reduce(reduce):
        TobaccoUseSummary(
            mode: .reduce,
            dailyAverageTenths: averageInTenths(reduce.last7Days.compactMap(\.units))
        )
    }
}

/// Mean in tenths, rounded half up with integer arithmetic. A day with no data is already filtered
/// out by the caller (it is not a zero); a logged zero stays in and pulls the mean down.
private func averageInTenths(_ units: [Int64]) -> Int? {
    if units.isEmpty {
        return nil
    }
    let count = Int64(units.count)
    return Int((units.reduce(0, +) * tenths + count / 2) / count)
}

private let msPerDay: Int64 = 86_400_000
private let tenths: Int64 = 10
