// The twin of `kotlinx.datetime.IllegalTimeZoneException`, which is what Kotlin throws from the
// two places this feature turns a stored or supplied time-zone identifier into a zone:
// `WeightEntryMapper.kt:16` and `SaveWeightEntryUseCase.kt:57`, both `TimeZone.of(id)`.
//
// It is one type rather than one per call site because it is one failure: an identifier the
// platform cannot resolve. Callers that want to tell the two apart already know which call they
// made.

/// A time-zone identifier that this platform cannot resolve.
public enum IllegalTimeZoneError: Error, Equatable {
    /// The identifier as it was stored or supplied, so a log or a repair tool can find the row.
    case unknownTimeZone(String)
}
