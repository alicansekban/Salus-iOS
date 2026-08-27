// The table for `ui/MedicationFormatting.swift`. Android has no test for
// `ui/MedicationFormatting.kt` — its three helpers are `@Composable`-adjacent and were only ever
// exercised through the screens — so this table is iOS-only and is opened as an Android gap in
// `salus-android/docs/ios-v1-plan.md` 11. The rules it pins are Kotlin's, line for line.

import Foundation
import SalusModel
import Testing

@testable import FeatureMedications

@Suite("MedicationFormatting")
struct MedicationFormattingTests {
    /// A Latin-digit locale so the assertions read the same wherever the host is set.
    private static let locale = Locale(identifier: "tr_TR")

    /// Sentinel labels rather than the shipped catalog: `swift test` copies `.xcstrings` verbatim
    /// instead of compiling it, so a live lookup would answer with the key and the assertions
    /// would stop describing the composition rule.
    private static let strings = ScheduleSummaryStrings(
        noSchedule: "no-schedule",
        daily: "daily",
        daysOfWeek: "days-of-week",
        asNeeded: "as-needed",
        everyNDays: { "every-\($0)-days" }
    )

    private func summary(_ schedules: [MedicationSchedule]) -> String {
        scheduleSummary(schedules: schedules, strings: Self.strings, locale: Self.locale)
    }

    /// `MedicationFormatting.kt:41-42` — whole numbers lose their ".0".
    @Test("formatAmount drops the trailing .0 from a whole number only")
    func formatAmountDropsTheTrailingZeroFromAWholeNumberOnly() {
        #expect(formatAmount(1.0) == "1")
        #expect(formatAmount(0.0) == "0")
        #expect(formatAmount(2.0) == "2")
        #expect(formatAmount(0.5) == "0.5")
        #expect(formatAmount(1.5) == "1.5")
        #expect(formatAmount(2.25) == "2.25")
        // Whole, but past `Int.max`: the trim is skipped rather than trapping. Twenty digits is
        // what a decimal keypad can reach, so this is not a theoretical input.
        #expect(formatAmount(1e20) == "1e+20")
    }

    /// `MedicationFormatting.kt:44-45`.
    @Test("formatTime pads both halves to two digits")
    func formatTimePadsBothHalvesToTwoDigits() {
        #expect(formatTime(minuteOfDay: 0, locale: Self.locale) == "00:00")
        #expect(formatTime(minuteOfDay: 480, locale: Self.locale) == "08:00")
        #expect(formatTime(minuteOfDay: 545, locale: Self.locale) == "09:05")
        #expect(formatTime(minuteOfDay: 1439, locale: Self.locale) == "23:59")
    }

    /// `MedicationFormatting.kt:49`.
    @Test("an empty schedule list reads as no schedule")
    func anEmptyScheduleListReadsAsNoSchedule() {
        #expect(summary([]) == "no-schedule")
    }

    /// `MedicationFormatting.kt:51-53` — AS_NEEDED returns before any time is rendered, so a
    /// time-of-day on such a schedule never reaches the summary.
    @Test("an as-needed first schedule swallows the times")
    func anAsNeededFirstScheduleSwallowsTheTimes() {
        #expect(
            summary([
                testSchedule(recurrence: .asNeeded, timeOfDayMinutes: 480),
                testSchedule(id: "sch-2", timeOfDayMinutes: 1200)
            ]) == "as-needed"
        )
    }

    /// `MedicationFormatting.kt:54-55, 65` — recurrence from the FIRST schedule, times from ALL
    /// of them, sorted, comma-separated, joined with a spaced middle dot.
    @Test("the summary is the first recurrence label then every time, sorted")
    func theSummaryIsTheFirstRecurrenceLabelThenEveryTimeSorted() {
        #expect(
            summary([
                testSchedule(id: "evening", timeOfDayMinutes: 20 * 60),
                testSchedule(id: "morning", timeOfDayMinutes: 8 * 60)
            ]) == "daily · 08:00, 20:00"
        )
        #expect(
            summary([testSchedule(recurrence: .daysOfWeek, daysOfWeekMask: 0b101)])
                == "days-of-week · 08:00"
        )
    }

    /// `MedicationFormatting.kt:61-62` — the interval label falls back to 1 when the column is
    /// null, so a half-written schedule still renders a sentence.
    @Test("the interval label reads the schedule interval and falls back to one day")
    func theIntervalLabelReadsTheScheduleIntervalAndFallsBackToOneDay() {
        #expect(
            summary([testSchedule(recurrence: .intervalDays, intervalDays: 3)])
                == "every-3-days · 08:00"
        )
        #expect(
            summary([testSchedule(recurrence: .intervalDays, intervalDays: nil)])
                == "every-1-days · 08:00"
        )
    }
}
