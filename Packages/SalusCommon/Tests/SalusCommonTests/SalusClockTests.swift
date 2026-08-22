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
