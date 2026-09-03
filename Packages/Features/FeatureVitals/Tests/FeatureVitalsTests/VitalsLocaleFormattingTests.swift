// No Kotlin twin: everything here is `private` inside `VitalsScreen.kt` / `VitalsViewModel.kt` and
// Compose screens carry no test file, so every case is iOS-only.
//
// The divergence being pinned is iOS-only too. `AppCompatDelegate.setApplicationLocales` moves
// Android's `Locale.getDefault()`, so a formatter reading the platform default already speaks the
// in-app language; nothing moves iOS's `Locale.current`. While the row date, the chart's axis and
// the values defaulted to `Locale.current`, an English device with Turkish picked in-app drew
// "23 Aug 2026, 23:09" and "72.5 kg" under a Home header written in Turkish. Each of them now
// takes the locale the shell publishes as `\.locale`, and each case below proves the answer is
// decided by that argument rather than by whatever language the machine running the tests uses.

import Foundation
import SalusModel
import SalusUI
import Testing

@testable import FeatureVitals

@MainActor
@Suite("Vitals formatting follows the app locale")
struct VitalsLocaleFormattingTests {
    private static let turkish = Locale(identifier: "tr")
    private static let english = Locale(identifier: "en_US")

    /// 2026-08-23 at 23:09 — the reading the bug report quoted.
    private static let measuredAt = LocalDateTime(
        date: LocalDate(year: 2026, month: 8, day: 23),
        minuteOfDay: 23 * 60 + 9
    )
    private static let day = measuredAt.date.epochDay

    // MARK: - The row

    @Test("a row's date is written in the locale it is handed")
    func rowDate() {
        #expect(vitalsRowDate(Self.measuredAt, locale: Self.turkish) == "23 Ağu 2026, 23:09")
        #expect(vitalsRowDate(Self.measuredAt, locale: Self.english) == "23 Aug 2026, 23:09")
    }

    @Test("a row's value carries the reader's decimal separator")
    func rowValue() {
        let weight = VitalsListItem.weight(
            VitalsListItem.Weight(id: "w1", measuredAt: Self.measuredAt, kilograms: 72.5, note: nil)
        )
        #expect(weight.headline(locale: Self.turkish) == "72,5 kg")
        #expect(weight.headline(locale: Self.english) == "72.5 kg")
        #expect(formatGlucose(5.5, unit: .mmolL, locale: Self.turkish) == "5,5 mmol/L")
        #expect(formatGlucose(5.5, unit: .mmolL, locale: Self.english) == "5.5 mmol/L")
    }

    // MARK: - The chart

    /// `xLabel` is `@Sendable` and cannot capture a `DateFormatter`, so the locale is captured
    /// instead and the formatter is built per call — this is the assertion that the captured value
    /// is the one that was passed in.
    @Test("the chart's axis labels are written in the locale the builder is handed")
    func axisLabels() {
        let turkishChart = chart(in: Self.turkish)
        let englishChart = chart(in: Self.english)

        #expect(turkishChart?.xLabel(Self.day) == "23 Ağu")
        #expect(englishChart?.xLabel(Self.day) == "23 Aug")
        #expect(turkishChart?.yLabel(72.5) == "72,5")
        #expect(englishChart?.yLabel(72.5) == "72.5")
    }

    /// Both charts are built in the same process, so at most one of them can be speaking the host's
    /// language — and neither may be falling back to it.
    @Test("the language comes from the argument, never from the host")
    func hostLocaleCannotReach() {
        #expect(chart(in: Self.turkish)?.xLabel(Self.day) != chart(in: Self.english)?.xLabel(Self.day))
        #expect(
            vitalsRowDate(Self.measuredAt, locale: Self.turkish)
                != vitalsRowDate(Self.measuredAt, locale: Self.english)
        )
    }

    private func chart(in locale: Locale) -> ChartUiModel? {
        VitalsViewModel.chartOrNull(
            [
                ChartPoint(xEpochDay: Self.day, y: 72.5),
                ChartPoint(xEpochDay: Self.day + 1, y: 72.9)
            ],
            locale: locale,
            yLabel: VitalsViewModel.decimalYLabel(locale: locale)
        )
    }
}
