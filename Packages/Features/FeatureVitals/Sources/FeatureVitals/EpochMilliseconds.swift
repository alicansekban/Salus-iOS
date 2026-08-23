// The two conversions Kotlin gets from the standard library and Swift does not:
// `Instant.fromEpochMilliseconds(...)` and `Instant.toEpochMilliseconds()`, which
// `WeightEntryMapper.kt`, `VitalsRepositoryImpl.kt` and `SaveWeightEntryUseCase.kt` all call.
//
// They live in one file rather than three because the three uses must agree to the millisecond:
// `measured_at_epoch_ms` is matched verbatim across platforms inside a backup archive
// (`docs/contracts/backup-format-v1.md`), and a row that came back one millisecond short would
// read as a different measurement on Android.
//
// This is not a *day* conversion, so `CLAUDE.md`'s `LocalDate`/`epochDay` rule does not apply and
// no `Calendar` appears below: an epoch-millisecond column is an absolute instant, which is
// exactly what `Date` is.

import Foundation

extension Date {
    /// The twin of `Instant.fromEpochMilliseconds(_:)`.
    init(epochMilliseconds: Int64) {
        self.init(timeIntervalSince1970: Double(epochMilliseconds) / 1000)
    }

    /// The twin of `Instant.toEpochMilliseconds()`.
    ///
    /// **Rounded, not truncated** — deliberately the opposite of `SalusClock.nowEpochMilliseconds()`,
    /// and for a different job. That one stamps *now*, where truncating is what keeps a stamp out
    /// of the future. This one has to invert `Date(epochMilliseconds:)` exactly: a `Date` holds
    /// seconds as a `Double`, and truncating a value that is a hair under the millisecond it was
    /// built from would lose a millisecond on every round trip through the database. Doubles happen
    /// to divide and multiply by 1000 exactly at today's epoch, so the two spellings agree in
    /// practice — rounding is the one that does not depend on that staying true.
    var epochMilliseconds: Int64 {
        Int64((timeIntervalSince1970 * 1000).rounded())
    }
}
