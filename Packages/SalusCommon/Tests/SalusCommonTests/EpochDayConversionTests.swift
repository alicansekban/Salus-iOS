import Foundation
import Testing

@testable import SalusCommon

// The instant <-> day pair the smoking calculator buckets by (iOS-M17 plan, ruling P2). The cases
// pin the two things that matter to a per-day money sum: the day boundary moves with the zone, and
// a daylight-saving day is 23 hours long, so durations never come from day arithmetic.

@Suite("Epoch day conversion")
struct EpochDayConversionTests {
    private let istanbul = TimeZone(identifier: "Europe/Istanbul") ?? .gmt
    private let berlin = TimeZone(identifier: "Europe/Berlin") ?? .gmt

    // 2026-03-29T21:30:00Z is 00:30 on 30 March in Istanbul (UTC+3, no daylight saving).
    private let istanbulPastMidnightMs: Int64 = 1_774_819_800_000
    private let march29EpochDay: Int64 = 20541

    @Test("the day number follows the zone, not UTC")
    func dayNumberFollowsTheZone() {
        #expect(epochDay(of: istanbulPastMidnightMs, in: istanbul) == march29EpochDay + 1)
        #expect(epochDay(of: istanbulPastMidnightMs, in: .gmt) == march29EpochDay)
    }

    @Test("the last millisecond of a local day still belongs to it")
    func lastMillisecondBelongsToTheDay() {
        // 2026-03-29T20:59:59.999Z is 23:59:59.999 in Istanbul.
        #expect(epochDay(of: 1_774_817_999_999, in: istanbul) == march29EpochDay)
        #expect(epochDay(of: 1_774_818_000_000, in: istanbul) == march29EpochDay + 1)
    }

    @Test("an instant before 1970 floors to the previous day rather than truncating toward zero")
    func negativeInstantFloors() {
        #expect(epochDay(of: -1, in: .gmt) == -1)
    }

    @Test("the start of a day in a fixed-offset zone is local midnight")
    func startOfDayInIstanbul() {
        // Local midnight of 30 March in Istanbul is 21:00Z on the 29th.
        #expect(startOfDayMs(epochDay: march29EpochDay + 1, in: istanbul) == 1_774_818_000_000)
    }

    @Test("a spring-forward day in Berlin is 23 hours long")
    func daylightSavingDayIs23Hours() {
        let start = startOfDayMs(epochDay: march29EpochDay, in: berlin)
        let next = startOfDayMs(epochDay: march29EpochDay + 1, in: berlin)
        #expect(start == 1_774_738_800_000)
        #expect(next - start == 23 * 3_600_000)
    }

    @Test("the start of a day maps back to that same day")
    func startOfDayRoundTrips() {
        for day in [Int64(-1), 0, march29EpochDay, march29EpochDay + 1] {
            #expect(epochDay(of: startOfDayMs(epochDay: day, in: berlin), in: berlin) == day)
        }
    }
}
