// The twin of `feature/trends/src/main/res/values/strings.xml` (Turkish, the source language) and
// `feature/trends/src/main/res/values-en/strings.xml` — the `trends_*` keys name and text verbatim,
// resolved against this package's own bundle exactly as `R.string` resolves against
// `:feature:trends`.
//
// Task 1 ships the skeleton's keys (title, back, the four ranges, the locked/empty/error bodies);
// the four cards' keys arrive with the analysis tasks that draw them (Task 2's time-of-day, Task
// 3's overlay, Task 4's dose weeks, Task 5's summaries). Each task extends this enum, the catalog
// and the key-set pin together.
//
// PLACEHOLDER MAPPING, the one place the port is not byte-for-byte. None of Task 1's keys carries a
// specifier, so there is no `%1$s`→`%1$@` / `%1$d`→`%1$lld` rewrite to record here — the mapping is
// the standing one from `CLAUDE.md`, applied the day a key with a placeholder arrives.
//
// TOOLCHAIN NOTE, and it costs an hour to rediscover: a `.xcstrings` catalog is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only. Command-line `swift build` /
// `swift test` copies the catalog into the resource bundle verbatim, so a lookup under
// `swift test` finds no table and `String(localized:)` returns the key. That is why the tests
// assert against the FILE, never against a resolved string; the end-to-end check is the simulator
// run, which `scripts/build-app.sh` builds for.

import Foundation
import SalusCommon

/// The strings `:feature:trends` owns.
public enum TrendsStrings {
    public static var title: String { localized(.title) }
    public static var back: String { localized(.back) }

    public static var rangeMonth: String { localized(.rangeMonth) }
    public static var rangeQuarter: String { localized(.rangeQuarter) }
    public static var rangeHalfYear: String { localized(.rangeHalfYear) }
    public static var rangeYear: String { localized(.rangeYear) }

    public static var lockedTitle: String { localized(.lockedTitle) }
    public static var lockedMessage: String { localized(.lockedMessage) }
    public static var lockedAction: String { localized(.lockedAction) }

    public static var emptyTitle: String { localized(.emptyTitle) }
    public static var emptyMessage: String { localized(.emptyMessage) }

    public static var errorTitle: String { localized(.errorTitle) }
    public static var errorMessage: String { localized(.errorMessage) }
    public static var errorAction: String { localized(.errorAction) }

    // MARK: - Time of day (Task 2)

    public static var timeOfDayTitle: String { localized(.timeOfDayTitle) }

    public static var dayPartMorning: String { localized(.dayPartMorning) }
    public static var dayPartMidday: String { localized(.dayPartMidday) }
    public static var dayPartEvening: String { localized(.dayPartEvening) }
    public static var dayPartNight: String { localized(.dayPartNight) }

    public static var metricBloodPressure: String { localized(.metricBloodPressure) }
    public static var metricGlucose: String { localized(.metricGlucose) }
    public static var metricWeight: String { localized(.metricWeight) }

    /// `%1$s (%2$s)` — a metric name followed by the unit its numbers are written in.
    public static func metricWithUnit(_ metric: String, _ unit: String) -> String {
        String(format: localized(.metricWithUnit), metric, unit)
    }

    /// `%1$d/%2$d` — systolic over diastolic, the way a blood pressure reading is written.
    public static func valueBloodPressure(_ systolic: Int, _ diastolic: Int) -> String {
        String(format: localized(.valueBloodPressure), systolic, diastolic)
    }

    /// `%1$s %2$s` — one bucket inside the chart's spoken summary: label then value.
    public static func timeOfDayPartSummary(_ label: String, _ value: String) -> String {
        String(format: localized(.timeOfDayPartSummary), label, value)
    }

    /// `%1$s, gün içi ortalamalar: %2$s` — the chart's spoken summary.
    public static func timeOfDayChartDescription(_ metric: String, _ parts: String) -> String {
        String(format: localized(.timeOfDayChartDescription), metric, parts)
    }

    public static var unitBloodPressure: String { localized(.unitBloodPressure) }
    public static var unitGlucose: String { localized(.unitGlucose) }
    public static var unitGlucoseMmol: String { localized(.unitGlucoseMmol) }
    public static var unitWeight: String { localized(.unitWeight) }

    // MARK: - Multi-metric overlay (Task 3)

    public static var overlayTitle: String { localized(.overlayTitle) }

    public static var overlaySubtitle: String { localized(.overlaySubtitle) }
    public static var overlaySubtitleWeekly: String { localized(.overlaySubtitleWeekly) }

    /// `%1$s · %2$s–%3$s %4$s` — one legend line: metric, then the real range it covered, with
    /// its unit.
    public static func overlayLegendEntry(_ metric: String, _ min: String, _ max: String, _ unit: String) -> String {
        String(format: localized(.overlayLegendEntry), metric, min, max, unit)
    }

    /// `%1$s` — the chart's spoken summary: the metrics shown together.
    public static func overlayChartDescription(_ metrics: String) -> String {
        String(format: localized(.overlayChartDescription), metrics)
    }

    // MARK: - Dose weeks (Task 4)

    public static var doseWeeksTitle: String { localized(.doseWeeksTitle) }
    public static var doseWeeksSubtitle: String { localized(.doseWeeksSubtitle) }

    /// `%%%1$d` — the share sentence: `%` then the whole percent. Names what the number actually
    /// measures: the denominator is the doses that were written down, so this may never be
    /// shortened to a bare percentage.
    public static func doseWeeksTakenRatio(_ percent: Int) -> String {
        String(format: localized(.doseWeeksTakenRatio), percent)
    }

    /// `%1$s · %2$s` — one week's line: the week it started, then the share sentence.
    public static func doseWeeksWeekRatio(_ week: String, _ ratio: String) -> String {
        String(format: localized(.doseWeeksWeekRatio), week, ratio)
    }

    /// `%1$s %2$s %3$s` — one metric's weekly mean: name, value, unit.
    public static func doseWeeksAverage(_ metric: String, _ value: String, _ unit: String) -> String {
        String(format: localized(.doseWeeksAverage), metric, value, unit)
    }

    /// `%1$s ile %2$s arası haftalar` — the chart's spoken summary: what it plots and the span it
    /// covers. The weeks themselves are announced by the rows under the chart, not repeated here.
    public static func doseWeeksChartDescription(_ first: String, _ last: String) -> String {
        String(format: localized(.doseWeeksChartDescription), first, last)
    }

    // MARK: - Metric summary (Task 5)

    public static var summaryTitle: String { localized(.summaryTitle) }
    public static var summarySubtitle: String { localized(.summarySubtitle) }

    /// `%1$d · Ortalama: %2$s %3$s` — one metric's counts: how many readings the period holds,
    /// then their mean and its unit.
    public static func summaryStats(_ count: Int, _ average: String, _ unit: String) -> String {
        String(format: localized(.summaryStats), count, average, unit)
    }

    /// `%1$s–%2$s %3$s` — the lowest and the highest reading of the period, in the unit they are
    /// written in.
    public static func summaryMinMax(_ min: String, _ max: String, _ unit: String) -> String {
        String(format: localized(.summaryMinMax), min, max, unit)
    }

    public static var summaryDirectionRising: String { localized(.summaryDirectionRising) }
    public static var summaryDirectionFalling: String { localized(.summaryDirectionFalling) }
    public static var summaryDirectionStable: String { localized(.summaryDirectionStable) }

    /// `%%%1$s arttı` — the change sentences. The sign lives in the verb rather than in front of
    /// the number, and the percentage is written with the sign before it the way Turkish writes
    /// one.
    public static func summaryChangeUp(_ percent: String) -> String {
        String(format: localized(.summaryChangeUp), percent)
    }

    public static func summaryChangeDown(_ percent: String) -> String {
        String(format: localized(.summaryChangeDown), percent)
    }

    public static var summaryChangeFlat: String { localized(.summaryChangeFlat) }
    public static var summaryChangeNoPrevious: String { localized(.summaryChangeNoPrevious) }
    public static var summaryChangeNotComputable: String { localized(.summaryChangeNotComputable) }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        case title = "trends_title"
        case back = "trends_back"

        case rangeMonth = "trends_range_month"
        case rangeQuarter = "trends_range_quarter"
        case rangeHalfYear = "trends_range_half_year"
        case rangeYear = "trends_range_year"

        case lockedTitle = "trends_locked_title"
        case lockedMessage = "trends_locked_message"
        case lockedAction = "trends_locked_action"

        case emptyTitle = "trends_empty_title"
        case emptyMessage = "trends_empty_message"

        case errorTitle = "trends_error_title"
        case errorMessage = "trends_error_message"
        case errorAction = "trends_error_action"

        case timeOfDayTitle = "trends_time_of_day_title"

        case dayPartMorning = "trends_day_part_morning"
        case dayPartMidday = "trends_day_part_midday"
        case dayPartEvening = "trends_day_part_evening"
        case dayPartNight = "trends_day_part_night"

        case metricBloodPressure = "trends_metric_blood_pressure"
        case metricGlucose = "trends_metric_glucose"
        case metricWeight = "trends_metric_weight"

        case metricWithUnit = "trends_metric_with_unit"
        case valueBloodPressure = "trends_value_blood_pressure"
        case timeOfDayPartSummary = "trends_time_of_day_part_summary"
        case timeOfDayChartDescription = "trends_time_of_day_chart_description"

        case unitBloodPressure = "trends_unit_blood_pressure"
        case unitGlucose = "trends_unit_glucose"
        case unitGlucoseMmol = "trends_unit_glucose_mmol"
        case unitWeight = "trends_unit_weight"

        case overlayTitle = "trends_overlay_title"

        case overlaySubtitle = "trends_overlay_subtitle"
        case overlaySubtitleWeekly = "trends_overlay_subtitle_weekly"
        case overlayLegendEntry = "trends_overlay_legend_entry"
        case overlayChartDescription = "trends_overlay_chart_description"

        case doseWeeksTitle = "trends_dose_weeks_title"
        case doseWeeksSubtitle = "trends_dose_weeks_subtitle"
        case doseWeeksTakenRatio = "trends_dose_weeks_taken_ratio"
        case doseWeeksWeekRatio = "trends_dose_weeks_week_ratio"
        case doseWeeksAverage = "trends_dose_weeks_average"
        case doseWeeksChartDescription = "trends_dose_weeks_chart_description"

        case summaryTitle = "trends_summary_title"
        case summarySubtitle = "trends_summary_subtitle"
        case summaryStats = "trends_summary_stats"
        case summaryMinMax = "trends_summary_min_max"
        case summaryDirectionRising = "trends_summary_direction_rising"
        case summaryDirectionFalling = "trends_summary_direction_falling"
        case summaryDirectionStable = "trends_summary_direction_stable"
        case summaryChangeUp = "trends_summary_change_up"
        case summaryChangeDown = "trends_summary_change_down"
        case summaryChangeFlat = "trends_summary_change_flat"
        case summaryChangeNoPrevious = "trends_summary_change_no_previous"
        case summaryChangeNotComputable = "trends_summary_change_not_computable"
    }

    private static func localized(_ key: Key) -> String {
        SalusLocalization.string(key.rawValue, bundle: .module)
    }
}
