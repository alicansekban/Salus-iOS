// No Android twin (spec §11 A8): `EditorMeasuredAt.kt` is covered on Android only through the
// editor ViewModel tests, and its two composition rules — now for today, midday for a past day —
// are exactly the kind of boundary a 1:1 port has to pin directly.
//
// Every expectation is derived from the clock's own API rather than from a hard-coded timestamp, so
// the table says what the rule *is* instead of restating one arithmetic answer.

import Foundation
import SalusCommon
import SalusModel
import SalusTesting
import Testing

@testable import FeatureVitals

@Suite("resolveEditorMeasuredAt")
struct EditorMeasuredAtTests {
    private static let now = Date(timeIntervalSince1970: 1_755_000_000)

    private let clock = FixedSalusClock(now: EditorMeasuredAtTests.now, timeZone: FixedSalusClock.defaultZone)

    /// `EditorMeasuredAt.kt:36` — `if (date == clock.today()) clock.localTimeNow()`.
    @Test("today resolves to the current time")
    func todayResolvesToTheCurrentTime() {
        let resolved = resolveEditorMeasuredAt(
            clock: clock,
            selectedEpochDay: clock.todayEpochDay(),
            existingMeasuredAt: nil,
            existingTimeZone: nil
        )

        #expect(resolved == clock.instant(of: clock.today(), minuteOfDay: clock.minuteOfDayNow()))
    }

    /// `EditorMeasuredAt.kt:13, 36` — `MIDDAY = LocalTime(12, 0)` for any day that is not today.
    @Test("a past day resolves to midday")
    func aPastDayResolvesToMidday() {
        let pastDay = clock.todayEpochDay() - 3

        let resolved = resolveEditorMeasuredAt(
            clock: clock,
            selectedEpochDay: pastDay,
            existingMeasuredAt: nil,
            existingTimeZone: nil
        )

        #expect(resolved == clock.instant(of: LocalDate(epochDay: pastDay), minuteOfDay: 12 * 60))
    }

    /// `EditorMeasuredAt.kt:32-34` — an edit that leaves the date alone keeps the original
    /// timestamp, so re-saving a reading never moves it to midday or to now.
    @Test("an unchanged date keeps the original instant")
    func anUnchangedDateKeepsTheOriginalInstant() {
        let existing = Self.now.addingTimeInterval(-5 * 86400)
        let existingDay = LocalDate(epochDay: clock.todayEpochDay() - 5)

        let resolved = resolveEditorMeasuredAt(
            clock: clock,
            selectedEpochDay: existingDay.epochDay,
            existingMeasuredAt: existing,
            existingTimeZone: clock.timeZone()
        )

        #expect(resolved == existing)
        // The same entry with no date selected at all — Kotlin's `selectedEpochDay == null` arm.
        #expect(
            resolveEditorMeasuredAt(
                clock: clock,
                selectedEpochDay: nil,
                existingMeasuredAt: existing,
                existingTimeZone: clock.timeZone()
            ) == existing
        )
    }

    /// `EditorMeasuredAt.kt:28` — `toLocalDateTime(existingTimeZone ?: zone)`: the day an existing
    /// reading falls on is read in the zone it was *taken* in, not in the clock's.
    ///
    /// The instant below is 20:00 UTC, which is the same calendar day in Istanbul (23:00) and the
    /// next one twelve hours east (08:00). Selecting the eastern day therefore has to count as
    /// "unchanged" — if the clock's zone were used the day would differ by one and the function
    /// would compose a fresh midday instant instead.
    @Test("the existing entry's own zone decides which day it falls on")
    func theExistingEntrysOwnZoneDecidesWhichDayItFallsOn() throws {
        let twelveHoursEast = try #require(TimeZone(secondsFromGMT: 12 * 60 * 60))
        // 20:00 UTC on the day before today, so the reading is safely in the past.
        let utcMidnight = Double((clock.todayEpochDay() - 1) * 86400)
        let existing = Date(timeIntervalSince1970: utcMidnight + 20 * 3600)
        let easternDay = clock.todayEpochDay()

        let resolved = resolveEditorMeasuredAt(
            clock: clock,
            selectedEpochDay: easternDay,
            existingMeasuredAt: existing,
            existingTimeZone: twelveHoursEast
        )

        #expect(resolved == existing)
        // The control: read in the clock's own zone the reading falls on the previous day, so the
        // same selection is a *changed* date and composes a new instant.
        let inClockZone = resolveEditorMeasuredAt(
            clock: clock,
            selectedEpochDay: easternDay,
            existingMeasuredAt: existing,
            existingTimeZone: clock.timeZone()
        )
        #expect(inClockZone != existing)
    }
}
