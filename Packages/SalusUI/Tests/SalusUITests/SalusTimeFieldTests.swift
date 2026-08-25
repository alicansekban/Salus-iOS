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

/// Which face the field draws, and — the point of the whole arrangement — that merely opening the
/// picker is not a choice. Kotlin seeds `rememberTimePickerState` at 9 and still requires the OK
/// button (`AppointmentEditorScreen.kt:367-380`); Cancel leaves the editor's `minuteOfDay` null and
/// the "pick a date and time" error intact, which is what `.picker(seed:)` preserves here.
@Suite("SalusTimeFieldState.displayMode")
struct SalusTimeFieldStateTests {
    @Test("nothing picked and the picker closed draws the placeholder button")
    func closedWithNoValueIsThePlaceholder() {
        let mode = SalusTimeFieldState.displayMode(minuteOfDay: nil, isPicking: false, seedMinuteOfDay: 540)

        #expect(mode == .placeholder)
    }

    @Test("opening the picker shows the wheel at the seed, and records nothing")
    func openingShowsTheWheelAtTheSeed() {
        let mode = SalusTimeFieldState.displayMode(minuteOfDay: nil, isPicking: true, seedMinuteOfDay: 540)

        // The seed is what the wheel *shows*. The state it would report is still nil — the mode
        // says `picker`, never `bound`, so nothing downstream can mistake it for a chosen time.
        #expect(mode == .picker(seed: 540))
    }

    @Test("a chosen time binds the field, whether or not the picker was opened")
    func aChosenTimeBindsTheField() {
        #expect(
            SalusTimeFieldState.displayMode(minuteOfDay: 630, isPicking: false, seedMinuteOfDay: 540)
                == .bound(minuteOfDay: 630)
        )
        #expect(
            SalusTimeFieldState.displayMode(minuteOfDay: 630, isPicking: true, seedMinuteOfDay: 540)
                == .bound(minuteOfDay: 630)
        )
    }

    @Test("midnight is a chosen time, not an absent one")
    func midnightIsAValue() {
        let mode = SalusTimeFieldState.displayMode(minuteOfDay: 0, isPicking: false, seedMinuteOfDay: 540)

        #expect(mode == .bound(minuteOfDay: 0))
    }

    /// A caller that clears the time is starting over; a picker left open would resume at the draft
    /// the last pick left behind instead of at the seed.
    @Test("clearing the time closes the picker, changing it does not")
    func clearingTheTimeClosesThePicker() {
        #expect(SalusTimeFieldState.clearsPicker(whenValueBecomes: nil))
        #expect(!SalusTimeFieldState.clearsPicker(whenValueBecomes: 630))
        #expect(!SalusTimeFieldState.clearsPicker(whenValueBecomes: 0))
    }
}
