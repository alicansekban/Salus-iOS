// The pure half of `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/list/VitalsViewModel.kt` (`:120-262`): given one window's entries — and, for glucose, the unit
// they are read in — the state the screen draws, plus the three chart helpers they share.
//
// **This is not a second type on Android.** Kotlin keeps all of it inside the `VitalsViewModel`
// class. It lives in its own file because, with the blood pressure and glucose branches ported,
// `VitalsViewModel.swift` sat at 499 of the 500-line `file_length` limit and its class body at 300
// of the 300-line `type_body_length` limit — both fatal under `swiftlint --strict`. A file with no
// headroom is a file the next task has to shave comments out of, so the split happened here rather
// than one edit later.
//
// The seam is an honest one and not a line count: everything here is a pure function of its
// arguments — no task, no subscription, nothing mutated — while the file next door is the flow
// graph and nothing else. Two consequences, both deliberate:
//
//   * These stay `extension VitalsViewModel` rather than a free `enum` of static functions, so the
//     call sites in `republish()` keep reading like the Kotlin they port, `buildWeightState(range,
//     entries)`, and every `VitalsViewModel.kt:NNN` citation below keeps pointing at a method of
//     the same class on both platforms.
//   * `VitalsViewModel.clock` is therefore internal rather than private: `private` reaches an
//     extension only inside the declaring file, and the zone every builder reads comes from it.
//     Nothing else about the ViewModel's surface widened.

import Foundation
import SalusCommon
import SalusModel
import SalusUI

@MainActor
extension VitalsViewModel {
    /// `VitalsViewModel.kt:120-149`.
    func buildWeightState(range: ChartRange, entries: [WeightEntry]) -> VitalsUiState {
        let zone = clock.timeZone()
        let sortedAscending = entries.sorted { $0.measuredAt < $1.measuredAt }

        // `mapIndexed` over the ascending window, then `asReversed()`: the delta is against the
        // entry *before* this one in time, and the list is drawn newest first
        // (`VitalsViewModel.kt:124-137`).
        let items = sortedAscending
            .enumerated()
            .map { index, entry in
                let previous = index > 0 ? sortedAscending[index - 1].kilograms : nil
                return VitalsListItem.weight(
                    VitalsListItem.Weight(
                        id: entry.id,
                        measuredAt: entry.measuredAt.wallClock(in: zone),
                        kilograms: entry.kilograms,
                        note: entry.note,
                        delta: previous.map { entry.kilograms - $0 },
                        trend: previous.map {
                            VitalsRowTrend.of(delta: entry.kilograms - $0, previous: $0)
                        }
                    )
                )
            }
            .reversed()
            .map(\.self)

        let points = Self.dailyPoints(
            sortedAscending,
            zone: zone,
            measuredAt: { $0.measuredAt },
            yValue: { Float($0.kilograms) }
        )

        return VitalsUiState(
            isLoading: false,
            selectedType: .weight,
            entries: items,
            chart: Self.chartOrNull(points, locale: locale, yLabel: Self.decimalYLabel(locale: locale)),
            selectedRange: range,
            latestKilograms: sortedAscending.last?.kilograms
        )
    }

    /// `VitalsViewModel.kt:151-188`.
    ///
    /// `roundToInt` rounds half away from zero on a positive reading, which is what
    /// `Double.rounded()` does; a blood pressure is never negative, where the two would part.
    func buildBloodPressureState(
        range: ChartRange,
        entries: [BloodPressureEntry]
    ) -> VitalsUiState {
        let zone = clock.timeZone()
        let sortedAscending = entries.sorted { $0.measuredAt < $1.measuredAt }

        // Newest first, and typed rather than erased, because `latestBloodPressure` is the first of
        // these rows (`VitalsViewModel.kt:186`) and the state holds it as itself.
        let rows = sortedAscending
            .enumerated()
            .map { index, entry in
                // Systolic carries the row's direction: it is the number the chart plots as the
                // primary series, so the glyph and the line agree (`VitalsViewModel.kt:157-158`).
                let systolic = Double(Int(entry.systolic.rounded()))
                let previous = index > 0
                    ? Double(Int(sortedAscending[index - 1].systolic.rounded()))
                    : nil
                return VitalsListItem.BloodPressure(
                    id: entry.id,
                    measuredAt: entry.measuredAt.wallClock(in: zone),
                    systolic: Int(systolic),
                    diastolic: Int(entry.diastolic.rounded()),
                    pulse: entry.pulse.map { Int($0.rounded()) },
                    note: entry.note,
                    delta: previous.map { systolic - $0 },
                    trend: previous.map { VitalsRowTrend.of(delta: systolic - $0, previous: $0) }
                )
            }
            .reversed()
            .map(\.self)

        let measuredAt: (BloodPressureEntry) -> Date = { $0.measuredAt }
        let systolicPoints = Self.dailyPoints(
            sortedAscending,
            zone: zone,
            measuredAt: measuredAt,
            yValue: { Float($0.systolic) }
        )
        let diastolicPoints = Self.dailyPoints(
            sortedAscending,
            zone: zone,
            measuredAt: measuredAt,
            yValue: { Float($0.diastolic) }
        )
        // `chartOrNull(systolicPoints, wholeYLabel())?.copy(secondaryPoints = diastolicPoints)`
        // (`VitalsViewModel.kt:178`): the `MIN_CHART_POINTS` gate is the systolic series' alone,
        // and the diastolic series is attached to whatever survived it. A Swift struct has no
        // `copy`, so the model is rebuilt from its own parts.
        let chart = Self.chartOrNull(systolicPoints, locale: locale, yLabel: Self.wholeYLabel).map {
            ChartUiModel(
                points: $0.points,
                xLabel: $0.xLabel,
                yLabel: $0.yLabel,
                secondaryPoints: diastolicPoints
            )
        }

        return VitalsUiState(
            isLoading: false,
            selectedType: .bloodPressure,
            entries: rows.map(VitalsListItem.bloodPressure),
            chart: chart,
            selectedRange: range,
            latestBloodPressure: rows.first
        )
    }

    /// `VitalsViewModel.kt:190-234`.
    ///
    /// Storage is always canonical mg/dL; `unit` decides only how a stored reading is written out,
    /// so every row and every plotted point is converted here and nothing downstream converts again.
    func buildGlucoseState(
        range: ChartRange,
        entries: [GlucoseEntry],
        unit: GlucoseUnit
    ) -> VitalsUiState {
        let zone = clock.timeZone()
        let sortedAscending = entries.sorted { $0.measuredAt < $1.measuredAt }

        let rows = sortedAscending
            .enumerated()
            .map { index, entry in
                // Both sides of the subtraction are converted first, so the delta is in the unit
                // the row prints rather than in stored mg/dL (`VitalsViewModel.kt:200-201`).
                let value = GlucoseConversion.fromMgDl(entry.mgDl, unit: unit)
                let previous = index > 0
                    ? GlucoseConversion.fromMgDl(sortedAscending[index - 1].mgDl, unit: unit)
                    : nil
                return VitalsListItem.Glucose(
                    id: entry.id,
                    measuredAt: entry.measuredAt.wallClock(in: zone),
                    value: value,
                    unit: unit,
                    measurementContext: entry.measurementContext,
                    note: entry.note,
                    delta: previous.map { value - $0 },
                    trend: previous.map { VitalsRowTrend.of(delta: value - $0, previous: $0) }
                )
            }
            .reversed()
            .map(\.self)

        let points = Self.dailyPoints(
            sortedAscending,
            zone: zone,
            measuredAt: { $0.measuredAt },
            yValue: { Float(GlucoseConversion.fromMgDl($0.mgDl, unit: unit)) }
        )
        // `VitalsViewModel.kt:223` — mg/dL readings are whole numbers to a reader, mmol/L ones are
        // not, so the axis follows the unit rather than the series.
        let yLabel = unit == .mgDl ? Self.wholeYLabel : Self.decimalYLabel(locale: locale)

        return VitalsUiState(
            isLoading: false,
            selectedType: .bloodGlucose,
            entries: rows.map(VitalsListItem.glucose),
            chart: Self.chartOrNull(points, locale: locale, yLabel: yLabel),
            selectedRange: range,
            latestGlucose: rows.first,
            glucoseUnit: unit
        )
    }

    /// One point per day (last measurement wins) keeps the x axis monotonic
    /// (`VitalsViewModel.kt:236-246`).
    ///
    /// `associateBy` keeps the last value for a repeated key and the input is ascending, so the
    /// day's newest reading is the one plotted — `uniquingKeysWith: { _, last in last }` is that,
    /// spelled out.
    static func dailyPoints<T>(
        _ sortedAscending: [T],
        zone: TimeZone,
        measuredAt: (T) -> Date,
        yValue: (T) -> Float
    ) -> [ChartPoint] {
        let byDay = Dictionary(
            sortedAscending.map { (measuredAt($0).wallClock(in: zone).date.epochDay, $0) },
            uniquingKeysWith: { _, last in last }
        )
        return byDay
            .map { epochDay, entry in ChartPoint(xEpochDay: epochDay, y: yValue(entry)) }
            .sorted { $0.xEpochDay < $1.xEpochDay }
    }

    /// `VitalsViewModel.kt:248-256`.
    ///
    /// The `"d MMM"` axis label is produced from the epoch day through a `DateFormatter` pinned to
    /// GMT and `locale` — the twin of `LocalDate.ofEpochDay(…).format(ofPattern("d MMM",
    /// Locale.getDefault()))`. Never a `Calendar`: see `LocalDateTime.swift`.
    ///
    /// **`locale` is the environment locale, not `Locale.current`.** Android's `Locale.getDefault()`
    /// follows `setApplicationLocales`; nothing on iOS moves `Locale.current`, so the in-app pick
    /// only reaches a formatter if it is carried there — the shell publishes it as `\.locale`
    /// (`RootView+Locale.swift`) and `VitalsRoute` hands it to the ViewModel.
    ///
    /// The formatter is built inside the closure rather than captured, because `xLabel` is
    /// `@Sendable` and `DateFormatter` is not. `Locale` *is* `Sendable`, so it is captured.
    static func chartOrNull(
        _ points: [ChartPoint],
        locale: Locale,
        yLabel: @escaping @Sendable (Float) -> String
    ) -> ChartUiModel? {
        guard points.count >= minChartPoints else { return nil }
        return ChartUiModel(
            points: points,
            xLabel: { LocalDate(epochDay: $0).formatted(pattern: "d MMM", locale: locale) },
            yLabel: yLabel
        )
    }

    /// `VitalsViewModel.kt:258-259` — `String.format(Locale.getDefault(), "%.1f", value)`.
    ///
    /// A function of the locale rather than a stored closure, for the same reason as above: the
    /// separator between "72" and "5" is the reader's, and on iOS the reader's is the in-app pick.
    static func decimalYLabel(locale: Locale) -> @Sendable (Float) -> String {
        { String(format: "%.1f", locale: locale, Double($0)) }
    }

    /// `VitalsViewModel.kt:261-262` — `value.roundToInt().toString()`.
    static let wholeYLabel: @Sendable (Float) -> String = { value in
        String(Int(value.rounded()))
    }

    /// `VitalsViewModel.kt:282`.
    static let minChartPoints = 2
}
