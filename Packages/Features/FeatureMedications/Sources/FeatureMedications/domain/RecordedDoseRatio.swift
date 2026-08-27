// iOS-only. This file has no Kotlin twin: it replaces the Android calculator that divides TAKEN
// doses by the occurrences `DoseOccurrenceGenerator` expands, and it is a different computation,
// not a rename. Two reasons, and the scanner in `SalusTesting` is neither of them:
//
//   1. No `MISSED` intake row is ever written — the database stores facts (what the user did),
//      never a derived absence. Counting a dose the user never recorded as a failure turns the
//      absence of a record into a claim about someone's treatment (spec 7, 12).
//   2. The number the list card shows is therefore about RECORDS: of the doses you recorded, how
//      many did you record as taken. A medication you logged nothing for has no such number, so
//      it is absent from the result rather than reported as zero.
//
// Android owes the mirror change; opened in `salus-android/docs/ios-v1-plan.md` 11.

import SalusModel

/// PURE SWIFT. Per-medication `taken / recorded` over a day range.
enum RecordedDoseRatio {
    /// The fraction of the intake logs in the inclusive [fromEpochDay, toEpochDay] window that
    /// were recorded as TAKEN, keyed by medication id.
    ///
    /// Medications with zero recorded logs in the window are **absent** from the result — the
    /// caller decides what to draw for "nothing recorded", and it is never 0%.
    ///
    /// The raw fraction is returned; rounding to a whole percent is the view model's, so the
    /// rule lives in one place rather than being applied twice at different precisions.
    static func perMedication(
        logs: [IntakeLog],
        fromEpochDay: Int,
        toEpochDay: Int
    ) -> [String: Double] {
        var counts: [String: (taken: Int, recorded: Int)] = [:]
        for log in logs where log.epochDay >= fromEpochDay && log.epochDay <= toEpochDay {
            var entry = counts[log.medicationId] ?? (taken: 0, recorded: 0)
            entry.recorded += 1
            if log.status == .taken {
                entry.taken += 1
            }
            counts[log.medicationId] = entry
        }
        // `recorded` is at least 1 for every key the loop created, so the division is total.
        return counts.mapValues { Double($0.taken) / Double($0.recorded) }
    }
}
