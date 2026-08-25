import Foundation
import Testing

@testable import SalusUI

/// The `epochDay` ↔ `Date` conversion behind `SalusDateField`, the twin of Kotlin's
/// `selectedDateMillis / MILLIS_PER_DAY` (`EditorDateField.kt:35`) and of
/// `initialSelectedDateMillis = epochDay * MILLIS_PER_DAY` (`:29`) read back the other way.
///
/// SwiftUI's `DatePicker` speaks `Date`, this state speaks a day number, and the whole point of the
/// GMT pin is that no `Calendar` is built to bridge them. That makes the bridge pure arithmetic,
/// which is what this suite pins — the view itself is only a `#Preview` build.
@Suite("SalusDateFieldBinding")
struct SalusDateFieldTests {
    @Test("day 0 is 1970-01-01 — the epoch itself")
    func epochIsDayZero() {
        #expect(SalusDateFieldBinding.date(epochDay: 0).timeIntervalSince1970 == 0)
        #expect(SalusDateFieldBinding.epochDay(from: Date(timeIntervalSince1970: 0)) == 0)
    }

    @Test("a day round-trips through the picker's Date")
    func dayRoundTrips() {
        // 2026-08-17, the day the preview shows.
        let date = SalusDateFieldBinding.date(epochDay: 20678)

        #expect(date.timeIntervalSince1970 == 20678 * 86400)
        #expect(SalusDateFieldBinding.epochDay(from: date) == 20678)
    }

    /// The zone pin exists so a device east or west of GMT cannot shift the day by one; the
    /// arithmetic has to hold across the whole day, not just at its midnight.
    @Test("any instant within a day maps to that day, midnight and the last second alike")
    func anyInstantWithinTheDayFloorsToIt() {
        let midnight = 20678 * 86400.0

        #expect(SalusDateFieldBinding.epochDay(from: Date(timeIntervalSince1970: midnight)) == 20678)
        #expect(
            SalusDateFieldBinding.epochDay(from: Date(timeIntervalSince1970: midnight + 86399)) == 20678
        )
    }

    /// A birth date, say. Swift's integer division truncates toward zero, so a plain `/` would
    /// report day 0 for 1969-12-31; the floor has to be explicit.
    @Test("a day before the epoch is negative, floored rather than truncated toward zero")
    func daysBeforeTheEpochFloor() {
        #expect(SalusDateFieldBinding.date(epochDay: -1).timeIntervalSince1970 == -86400)
        #expect(SalusDateFieldBinding.epochDay(from: Date(timeIntervalSince1970: -1)) == -1)
        #expect(SalusDateFieldBinding.epochDay(from: Date(timeIntervalSince1970: -86400)) == -1)
    }
}

/// Which face the field draws, and — the point of the whole arrangement — that merely opening the
/// picker is not a choice. Kotlin's `DatePickerDialog` opens on a month and still requires the OK
/// button (`EditorDateField.kt:47-61`); Cancel leaves the editor's `dateEpochDay` null and the
/// editor's own validation intact, which is what `.picker(seed:)` preserves here.
@Suite("SalusDateFieldState.displayMode")
struct SalusDateFieldStateTests {
    @Test("nothing picked and the picker closed draws the placeholder button")
    func closedWithNoValueIsThePlaceholder() {
        let mode = SalusDateFieldState.displayMode(epochDay: nil, isPicking: false, seedEpochDay: 20678)

        #expect(mode == .placeholder)
    }

    @Test("opening the picker shows the wheel at the seed, and records nothing")
    func openingShowsTheWheelAtTheSeed() {
        let mode = SalusDateFieldState.displayMode(epochDay: nil, isPicking: true, seedEpochDay: 20678)

        // The seed is what the wheel *shows*. The day it would report is still nil — the mode says
        // `picker`, never `bound`, so nothing downstream can mistake it for a chosen day.
        #expect(mode == .picker(seed: 20678))
    }

    @Test("a chosen day binds the field, whether or not the picker was opened")
    func aChosenDayBindsTheField() {
        #expect(
            SalusDateFieldState.displayMode(epochDay: 20682, isPicking: false, seedEpochDay: 20678)
                == .bound(epochDay: 20682)
        )
        #expect(
            SalusDateFieldState.displayMode(epochDay: 20682, isPicking: true, seedEpochDay: 20678)
                == .bound(epochDay: 20682)
        )
    }

    @Test("the epoch itself is a chosen day, not an absent one")
    func dayZeroIsAValue() {
        let mode = SalusDateFieldState.displayMode(epochDay: 0, isPicking: false, seedEpochDay: 20678)

        #expect(mode == .bound(epochDay: 0))
    }

    /// A caller that clears the day is starting over; a picker left open would resume at the draft
    /// the last pick left behind instead of at the seed.
    @Test("clearing the day closes the picker, changing it does not")
    func clearingTheDayClosesThePicker() {
        #expect(SalusDateFieldState.clearsPicker(whenValueBecomes: nil))
        #expect(!SalusDateFieldState.clearsPicker(whenValueBecomes: 20682))
        #expect(!SalusDateFieldState.clearsPicker(whenValueBecomes: 0))
    }
}
