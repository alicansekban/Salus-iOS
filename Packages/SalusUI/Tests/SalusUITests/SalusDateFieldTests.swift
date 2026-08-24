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
