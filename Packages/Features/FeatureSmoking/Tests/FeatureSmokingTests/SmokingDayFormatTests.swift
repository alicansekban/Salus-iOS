// The history log's day labels: the fixed patterns of `SmokingHistoryScreen.kt`'s `formatDay` and
// `dayHeader`, in both languages.

import Foundation
import SalusTesting
import Testing

@testable import FeatureSmoking

@Suite("SmokingDayFormat")
struct SmokingDayFormatTests {
    private let turkish = Locale(identifier: "tr_TR")
    private let english = Locale(identifier: "en_US")
    private let zone = FixedSalusClock.defaultZone
    /// 2026-03-10T12:00 Europe/Istanbul.
    private let nowMs: Int64 = 1_773_133_200_000
    /// 2026-03-10 as an epoch day.
    private let today: Int64 = 20522

    @Test("an attempt's span uses the short pattern in the entry's own zone")
    func shortDay() {
        #expect(formatShortDay(epochMs: nowMs, zone: zone, locale: turkish) == "10 Mar 2026")
        #expect(formatShortDay(epochMs: nowMs, zone: zone, locale: english) == "10 Mar 2026")
        // 23:30 in Istanbul is still the 10th, though it is the 10th 20:30 UTC and the 11th 04:30
        // in Tokyo: the zone passed in decides.
        let lateEvening = nowMs + 11 * 60 * 60 * 1000 + 30 * 60 * 1000
        #expect(formatShortDay(epochMs: lateEvening, zone: zone, locale: english) == "10 Mar 2026")
        #expect(
            formatShortDay(epochMs: lateEvening, zone: TimeZone(identifier: "Asia/Tokyo") ?? .gmt, locale: english)
                == "11 Mar 2026"
        )
    }

    @Test("today and yesterday are named, any other day is written out")
    func dayHeader() {
        #expect(formatDayHeader(epochDay: today, todayEpochDay: today, locale: turkish) == SmokingStrings
            .historyDayToday)
        #expect(
            formatDayHeader(epochDay: today - 1, todayEpochDay: today, locale: turkish)
                == SmokingStrings.historyDayYesterday
        )
        #expect(formatDayHeader(epochDay: today - 2, todayEpochDay: today, locale: turkish) == "8 Mart 2026")
        #expect(formatDayHeader(epochDay: today - 2, todayEpochDay: today, locale: english) == "8 March 2026")
        // Tomorrow is not "today": the log never shows it, but the label must not lie if it did.
        #expect(formatDayHeader(epochDay: today + 1, todayEpochDay: today, locale: english) == "11 March 2026")
    }
}
