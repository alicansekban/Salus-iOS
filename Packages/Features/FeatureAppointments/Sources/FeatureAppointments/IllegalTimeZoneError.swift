// The twin of `kotlinx.datetime.IllegalTimeZoneException`, which is what Kotlin throws from the one
// place this feature turns a stored time-zone identifier into a zone: `AppointmentMapper.kt:22`,
// `TimeZone.of(timeZoneId)`.
//
// A byte-for-byte duplicate of `FeatureVitals/IllegalTimeZoneError.swift`, and deliberately so:
// features never depend on each other (`CLAUDE.md`), and the type is feature-local on both
// platforms. This is the same template-sanctioned duplicate as `CancellationBox`. The two copies
// are independent types — nothing catches one expecting the other — so the duplication costs a
// file, not a coupling.

/// A time-zone identifier that this platform cannot resolve.
public enum IllegalTimeZoneError: Error, Equatable {
    /// The identifier as it was stored, so a log or a repair tool can find the row.
    case unknownTimeZone(String)
}
