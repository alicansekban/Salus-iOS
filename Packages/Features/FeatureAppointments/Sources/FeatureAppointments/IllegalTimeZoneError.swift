// The twin of `kotlinx.datetime.IllegalTimeZoneException`, which is what Kotlin throws from the one
// place this feature turns a stored time-zone identifier into a zone: `AppointmentMapper.kt:22`,
// `TimeZone.of(timeZoneId)`.
//
// The same type as `FeatureVitals/IllegalTimeZoneError.swift`, deliberately duplicated: features
// never depend on each other (`CLAUDE.md`), and the type is feature-local on both platforms — it
// names a mapper's failure, not shared infrastructure, so it stays duplicated where
// `CancellationBox` and `latestOfBoth` were promoted to `SalusCommon` in iOS-M6. The declaration is
// identical; the comments are not, because each copy cites its own feature's call site — Vitals has two
// (`WeightEntryMapper.kt:16`, `SaveWeightEntryUseCase.kt:57`) and this one has the mapper alone.
// The two copies are independent types — nothing catches one expecting the other — so the
// duplication costs a file, not a coupling.

/// A time-zone identifier that this platform cannot resolve.
public enum IllegalTimeZoneError: Error, Equatable {
    /// The identifier as it was stored, so a log or a repair tool can find the row.
    case unknownTimeZone(String)
}
