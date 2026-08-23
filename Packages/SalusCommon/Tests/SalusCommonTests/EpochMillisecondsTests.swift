// Pins the one conversion every epoch-millisecond column in the tree goes through
// (`EpochMilliseconds.swift`), against Kotlin's `Instant.toEpochMilliseconds()` /
// `Instant.fromEpochMilliseconds()`.
//
// The column is matched verbatim across platforms inside a backup archive
// (`docs/contracts/backup-format-v1.md`), so both properties below are load-bearing: a clock
// reading floors the way Kotlin floors it, and a stored value survives a read/write round trip
// unchanged.

import Foundation
import Testing

@testable import SalusCommon

@Suite("Date.epochMilliseconds")
struct EpochMillisecondsTests {
    @Test("a sub-millisecond fraction is truncated, never rounded")
    func aSubMillisecondFractionIsTruncated() {
        // 1_700_000_000.9996 s is 1_700_000_000_999.6 ms: rounding would answer …_000, one
        // millisecond in the future. Kotlin floors, and so does this.
        let instant = Date(timeIntervalSince1970: 1_700_000_000.999_6)

        #expect(instant.epochMilliseconds == 1_700_000_000_999)
    }

    @Test("an exact instant answers whole milliseconds")
    func anExactInstantAnswersWholeMilliseconds() {
        #expect(Date(timeIntervalSince1970: 1_700_000_000).epochMilliseconds == 1_700_000_000_000)
        #expect(Date(timeIntervalSince1970: 0).epochMilliseconds == 0)
    }

    /// Kotlin's `epochSeconds * 1000 + nanosecondsOfSecond / 1_000_000` floors on both sides of the
    /// epoch, because `nanosecondsOfSecond` is never negative. Swift's plain `Int64(_:)` conversion
    /// truncates towards zero and would answer -1_499 here — the case where the two spellings
    /// disagree, and the reason this floors explicitly.
    @Test("an instant before 1970 floors, as Kotlin does, rather than truncating towards zero")
    func anInstantBeforeNineteenSeventyFloors() {
        #expect(Date(timeIntervalSince1970: -1.499_9).epochMilliseconds == -1500)
    }

    /// The property that a bare `.rounded(.down)` breaks. Each value below is one a floor applied
    /// to the raw `Double` answers one millisecond short, because `Date` stores seconds since 2001
    /// and cannot hold the reconstructed instant exactly. Two of them are ordinary timestamps —
    /// 2004 and 2038 — not edge cases.
    @Test("a value read out of a column and written straight back is unchanged")
    func aStoredValueSurvivesARoundTrip() {
        let stored: [Int64] = [
            0,
            1,
            -1,
            -1500,
            1_083_138_706_692, // 2004, loses a millisecond under a bare floor
            2_150_000_000_001, // 2038, likewise
            1_700_000_000_999,
            1_750_000_000_123
        ]

        for milliseconds in stored {
            #expect(Date(epochMilliseconds: milliseconds).epochMilliseconds == milliseconds)
        }
    }
}
