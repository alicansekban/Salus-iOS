// The two conversions Kotlin gets from the standard library and Swift does not:
// `Instant.fromEpochMilliseconds(_:)` and `Instant.toEpochMilliseconds()`.
//
// They live here, beside `SalusClock.nowEpochMilliseconds()`, because that method's rule — "every
// writer of an epoch-millisecond *column* goes through here, so the seed row and a repository write
// cannot disagree by a millisecond" — needs the column conversion to be made in exactly one place.
// `nowEpochMilliseconds()` is now a thin call onto `epochMilliseconds` for that reason: the clock
// decides *which* instant is stamped, this file decides how an instant becomes a column value, and
// the second decision is made once.
//
// That is a rule about *columns*, and it is deliberately narrower than "there is exactly one body of
// this arithmetic in the tree", which stopped being true in iOS-M4. `SalusModel`'s
// `Date.wallClock(in:)` carries a byte-identical private twin, `epochMillisecondsForWallClock`,
// because `SalusModel` sits *below* this package and cannot reach here. It writes no column — it
// floors an instant to a day and a minute — so the guarantee above is untouched, and the two bodies
// are pinned against each other by `SalusCommonTests`'
// `WallClockEpochMillisecondsAgreementTests`. Change one and change the other, or that suite fails.
//
// This is not a *day* conversion, so `CLAUDE.md`'s `LocalDate`/`epochDay` rule does not apply and
// no `Calendar` appears below: an epoch-millisecond column is an absolute instant, which is
// exactly what `Date` is.

import Foundation

extension Date {
    /// The twin of `Instant.fromEpochMilliseconds(_:)`.
    public init(epochMilliseconds: Int64) {
        self.init(timeIntervalSince1970: Double(epochMilliseconds) / 1000)
    }

    /// The twin of `Instant.toEpochMilliseconds()`.
    ///
    /// **Truncated, never rounded**, and truncated *downwards*. Kotlin computes
    /// `epochSeconds * 1000 + nanosecondsOfSecond / 1_000_000`, where `epochSeconds` is the floor
    /// of the instant and `nanosecondsOfSecond` is always in `0..<1_000_000_000`; that is a floor
    /// of the millisecond value, on both sides of the epoch. Swift's plain `Int64(_:)` conversion
    /// truncates towards zero instead and would disagree with Kotlin before 1970, so the floor is
    /// spelled out.
    ///
    /// **Why the microsecond step.** Kotlin's `Instant` holds seconds and nanoseconds as integers,
    /// so its floor is exact arithmetic. A `Date` holds one `Double` of seconds *since 2001*, so an
    /// instant rebuilt from a stored column — `Date(epochMilliseconds:)`, which every read does —
    /// comes back a fraction of a microsecond off, and flooring that raw value silently drops a
    /// whole millisecond whenever the error lands on the low side. That is not theoretical: over
    /// 200 000 sampled instants per era, a bare `.rounded(.down)` loses a millisecond on ~2% of
    /// 2030-2050 timestamps and ~2% of 2001-2010 ones (2015-2030 happens to be clean, which is why
    /// nothing catches it today). Quantising to microseconds first — `Date`'s honest resolution at
    /// this magnitude, and finer than any clock this app reads — removes the representation noise
    /// without touching a genuine sub-millisecond fraction, and *then* Kotlin's floor is applied.
    ///
    /// The result satisfies both things this has to be at once: a fractional instant from
    /// `SalusClock.now()` floors the way Kotlin floors it, so a stamp can never land in the future;
    /// and a value read out of an epoch-millisecond column and written straight back is the integer
    /// it started as, so a row cannot drift a millisecond per save. `measured_at_epoch_ms` and
    /// `created_at` are matched verbatim across platforms inside a backup archive
    /// (`docs/contracts/backup-format-v1.md`), which is what makes both properties load-bearing.
    public var epochMilliseconds: Int64 {
        let microseconds = (timeIntervalSince1970 * 1_000_000).rounded()
        return Int64((microseconds / 1000).rounded(.down))
    }
}
