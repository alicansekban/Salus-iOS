// The pure half of `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/list/VitalsViewModel.kt` (`:118-247`): given one window's entries — and, for glucose, the unit
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
    /// `VitalsViewModel.kt:118-144`.
    func buildWeightState(range: ChartRange, entries: [WeightEntry]) -> VitalsUiState {
        let zone = clock.timeZone()
        let sortedAscending = entries.sorted { $0.measuredAt < $1.measuredAt }

        let items = sortedAscending
            .reversed()
            .map { entry in
                VitalsListItem.weight(
                    VitalsListItem.Weight(
                        id: entry.id,
                        measuredAt: entry.measuredAt.wallClock(in: zone),
                        kilograms: entry.kilograms,
                        note: entry.note
                    )
                )
            }

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
            chart: Self.chartOrNull(points, yLabel: Self.decimalYLabel),
            selectedRange: range,
            latestKilograms: sortedAscending.last?.kilograms
        )
    }

    /// `VitalsViewModel.kt:146-177`.
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
        // these rows (`VitalsViewModel.kt:175`) and the state holds it as itself.
        let rows = sortedAscending
            .reversed()
            .map { entry in
                VitalsListItem.BloodPressure(
                    id: entry.id,
                    measuredAt: entry.measuredAt.wallClock(in: zone),
                    systolic: Int(entry.systolic.rounded()),
                    diastolic: Int(entry.diastolic.rounded()),
                    pulse: entry.pulse.map { Int($0.rounded()) },
                    note: entry.note
                )
            }

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
        // (`VitalsViewModel.kt:167`): the `MIN_CHART_POINTS` gate is the systolic series' alone,
        // and the diastolic series is attached to whatever survived it. A Swift struct has no
        // `copy`, so the model is rebuilt from its own parts.
        let chart = Self.chartOrNull(systolicPoints, yLabel: Self.wholeYLabel).map {
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

    /// `VitalsViewModel.kt:179-215`.
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
            .reversed()
            .map { entry in
                VitalsListItem.Glucose(
                    id: entry.id,
                    measuredAt: entry.measuredAt.wallClock(in: zone),
                    value: GlucoseConversion.fromMgDl(entry.mgDl, unit: unit),
                    unit: unit,
                    measurementContext: entry.measurementContext,
                    note: entry.note
                )
            }

        let points = Self.dailyPoints(
            sortedAscending,
            zone: zone,
            measuredAt: { $0.measuredAt },
            yValue: { Float(GlucoseConversion.fromMgDl($0.mgDl, unit: unit)) }
        )
        // `VitalsViewModel.kt:204` — mg/dL readings are whole numbers to a reader, mmol/L ones are
        // not, so the axis follows the unit rather than the series.
        let yLabel = unit == .mgDl ? Self.wholeYLabel : Self.decimalYLabel

        return VitalsUiState(
            isLoading: false,
            selectedType: .bloodGlucose,
            entries: rows.map(VitalsListItem.glucose),
            chart: Self.chartOrNull(points, yLabel: yLabel),
            selectedRange: range,
            latestGlucose: rows.first,
            glucoseUnit: unit
        )
    }

    /// One point per day (last measurement wins) keeps the x axis monotonic
    /// (`VitalsViewModel.kt:218-227`).
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

    /// `VitalsViewModel.kt:229-237`.
    ///
    /// The `"d MMM"` axis label is produced from the epoch day through a `DateFormatter` pinned to
    /// GMT and `Locale.current` — the twin of `LocalDate.ofEpochDay(…).format(ofPattern("d MMM",
    /// Locale.getDefault()))`. Never a `Calendar`: see `LocalDateTime.swift`.
    ///
    /// The formatter is built inside the closure rather than captured, because `xLabel` is
    /// `@Sendable` and `DateFormatter` is not.
    static func chartOrNull(
        _ points: [ChartPoint],
        yLabel: @escaping @Sendable (Float) -> String
    ) -> ChartUiModel? {
        guard points.count >= minChartPoints else { return nil }
        return ChartUiModel(
            points: points,
            xLabel: { epochDay in LocalDate(epochDay: epochDay).formatted(pattern: "d MMM") },
            yLabel: yLabel
        )
    }

    /// `VitalsViewModel.kt:239-240` — `String.format(Locale.getDefault(), "%.1f", value)`.
    static let decimalYLabel: @Sendable (Float) -> String = { value in
        String(format: "%.1f", locale: .current, Double(value))
    }

    /// `VitalsViewModel.kt:242-243` — `value.roundToInt().toString()`.
    static let wholeYLabel: @Sendable (Float) -> String = { value in
        String(Int(value.rounded()))
    }

    /// `VitalsViewModel.kt:245-247`.
    static let minChartPoints = 2
}
