import Foundation
import Testing

@testable import SalusCommon

// `SystemSalusClock` is the one part of the clock port that cannot be pinned against fixed values:
// it reads the device (`SalusClock.kt:26-31`). What is asserted here is that it reads the device
// and nothing else — the derived answers (`today()`, `todayEpochDay()`, `minuteOfDayNow()`) are
// pinned instant by instant in `SalusTesting`'s `FixedSalusClockTests`, which is where the fixed
// clock lives.

@Suite("SystemSalusClock")
struct SystemSalusClockTests {
    @Test("it reads the device clock")
    func itReadsTheDeviceClock() {
        // Wide on purpose: this asserts that `now()` is the current instant rather than a stub,
        // not how fast the machine is.
        #expect(abs(SystemSalusClock().now().timeIntervalSinceNow) < 5)
    }

    @Test("it reads the device time zone")
    func itReadsTheDeviceTimeZone() {
        // The twin of `TimeZone.currentSystemDefault()` (`SalusClock.kt:30`).
        #expect(SystemSalusClock().timeZone() == TimeZone.current)
    }
}

/// A clock frozen at one instant.
///
/// `SalusTesting`'s `FixedSalusClock` cannot be used here — `SalusTesting` depends on
/// `SalusCommon`, so importing it from this bundle would be a dependency cycle. A tiny local
/// conformer is enough for the one derived answer under test.
private struct StubClock: SalusClock {
    let instant: Date

    func now() -> Date {
        instant
    }

    func timeZone() -> TimeZone {
        TimeZone(identifier: "UTC") ?? .current
    }
}

@Suite("SalusClock.nowEpochMilliseconds")
struct SalusClockEpochMillisecondsTests {
    @Test("it truncates the sub-millisecond part rather than rounding it")
    func itTruncatesRatherThanRounds() {
        // 1_700_000_000.9996 s is 1_700_000_000_999.6 ms: rounding would answer …_000, one
        // millisecond in the future. `Instant.toEpochMilliseconds()` truncates, and so does this.
        let clock = StubClock(instant: Date(timeIntervalSince1970: 1_700_000_000.9996))
        #expect(clock.nowEpochMilliseconds() == 1_700_000_000_999)
    }

    @Test("it answers whole milliseconds for an exact instant")
    func itAnswersWholeMilliseconds() {
        let clock = StubClock(instant: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(clock.nowEpochMilliseconds() == 1_700_000_000_000)
    }
}
