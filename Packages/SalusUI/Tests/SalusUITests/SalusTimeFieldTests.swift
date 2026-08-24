import Foundation
import Testing

@testable import SalusUI

/// The `minuteOfDay` ↔ `Date` conversion behind `SalusTimeField`, the twin of Kotlin's
/// `timePickerState.hour * MINUTES_PER_HOUR + timePickerState.minute`
/// (`AppointmentEditorScreen.kt:377`) and of `rememberTimePickerState(initialHour, initialMinute)`
/// (`:367-370`) read back the other way.
///
/// SwiftUI's `DatePicker` speaks `Date`, this state speaks a minute-of-day integer, and the whole
/// point of the GMT pin is that no `Calendar` is built to bridge them. That makes the bridge pure
/// arithmetic, which is what this suite pins — the view itself is only a `#Preview` build.
@Suite("SalusTimeFieldBinding")
struct SalusTimeFieldTests {
    @Test("minute 0 is 00:00 GMT — the epoch itself")
    func midnightIsTheEpoch() {
        #expect(SalusTimeFieldBinding.date(minuteOfDay: 0).timeIntervalSince1970 == 0)
        #expect(SalusTimeFieldBinding.minuteOfDay(from: Date(timeIntervalSince1970: 0)) == 0)
    }

    @Test("minute 1439 is 23:59 GMT — the last minute of the day")
    func lastMinuteOfTheDay() {
        let date = SalusTimeFieldBinding.date(minuteOfDay: 1439)

        #expect(date.timeIntervalSince1970 == 1439 * 60)
        #expect(SalusTimeFieldBinding.minuteOfDay(from: date) == 1439)
    }

    @Test("every minute of the day round-trips")
    func everyMinuteRoundTrips() {
        for minute in 0 ..< 1440 {
            let roundTripped = SalusTimeFieldBinding.minuteOfDay(
                from: SalusTimeFieldBinding.date(minuteOfDay: minute)
            )
            #expect(roundTripped == minute)
        }
    }

    @Test("a date past midnight wraps back to 0 rather than reporting 1440")
    func wrapsAtMidnight() {
        let nextMidnight = Date(timeIntervalSince1970: 1440 * 60)

        #expect(SalusTimeFieldBinding.minuteOfDay(from: nextMidnight) == 0)
        #expect(SalusTimeFieldBinding.minuteOfDay(from: Date(timeIntervalSince1970: 1441 * 60)) == 1)
    }

    /// `DatePicker` hands back whatever the wheel shows; a picker seeded before the epoch would
    /// otherwise produce a negative minute, which is not a time of day. Swift's `%` keeps the
    /// sign of the dividend, so the wrap has to be spelled out.
    @Test("a date before the epoch still reports a time of day, never a negative minute")
    func beforeTheEpochStaysInRange() {
        #expect(SalusTimeFieldBinding.minuteOfDay(from: Date(timeIntervalSince1970: -60)) == 1439)
        #expect(SalusTimeFieldBinding.minuteOfDay(from: Date(timeIntervalSince1970: -1440 * 60)) == 0)
    }

    /// A seconds component the wheel cannot show must not round the minute up.
    @Test("seconds within a minute are truncated, not rounded")
    func secondsAreTruncated() {
        let date = Date(timeIntervalSince1970: 59)

        #expect(SalusTimeFieldBinding.minuteOfDay(from: date) == 0)
    }
}
