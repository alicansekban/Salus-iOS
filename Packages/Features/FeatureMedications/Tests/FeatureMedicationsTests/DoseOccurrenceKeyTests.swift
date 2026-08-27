// iOS-only table. Android has no test for `DoseOccurrenceKey.kt` — the codec is exercised there
// only through the reminder handler — but the key is a byte-for-byte contract between the
// scheduler that writes it and the receiver that reads it back, so it gets pinned here. Opened as
// an Android gap in `salus-android/docs/ios-v1-plan.md` 11.

import Testing

@testable import FeatureMedications

@Suite("DoseOccurrenceKey")
struct DoseOccurrenceKeyTests {
    @Test("encode writes epochDay, a pipe, then minuteOfDay")
    func encodeWritesEpochDayPipeMinuteOfDay() {
        #expect(DoseOccurrenceKey.encode(epochDay: 20514, minuteOfDay: 480) == "20514|480")
        // Negative days are pre-1970 and still round trip; the codec does no validation.
        #expect(DoseOccurrenceKey.encode(epochDay: -1, minuteOfDay: 0) == "-1|0")
    }

    @Test("decode round trips what encode wrote")
    func decodeRoundTripsWhatEncodeWrote() throws {
        for (day, minute) in [(20514, 480), (0, 0), (-1, 1439)] {
            let decoded = try #require(DoseOccurrenceKey.decode(DoseOccurrenceKey.encode(
                epochDay: day,
                minuteOfDay: minute
            )))

            #expect(decoded.epochDay == day)
            #expect(decoded.minuteOfDay == minute)
        }
    }

    @Test("malformed keys decode to nil")
    func malformedKeysDecodeToNil() {
        // Wrong number of parts, either way.
        #expect(DoseOccurrenceKey.decode("20514") == nil)
        #expect(DoseOccurrenceKey.decode("20514|480|0") == nil)
        #expect(DoseOccurrenceKey.decode("") == nil)
        // Two parts, but not both integers.
        #expect(DoseOccurrenceKey.decode("day|480") == nil)
        #expect(DoseOccurrenceKey.decode("20514|") == nil)
        #expect(DoseOccurrenceKey.decode("20514|8.5") == nil)
    }
}
