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
import SalusSmoking

/// The strings `:feature:trends` owns.
public enum TrendsStrings {
    public static var title: String { localized(.title) }

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

    /// The same metric names, stored upper-case for the places they are drawn as an overline
    /// (`TrendsCards.kt:549-560`). A second key rather than `uppercase()`: Turkish folds `i` to
    /// `İ` and a runtime fold depends on the device's locale, not on the resource.
    public static var metricBloodPressureOverline: String { localized(.metricBloodPressureOverline) }
    public static var metricGlucoseOverline: String { localized(.metricGlucoseOverline) }
    public static var metricWeightOverline: String { localized(.metricWeightOverline) }

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

    /// `%1$lld · Ortalama: %2$@ %3$@` — one metric's counts: how many readings the period holds,
    /// then their mean and its unit.
    public static func summaryCount(_ count: Int) -> String {
        String(format: localized(.summaryCount), count)
    }

    /// `%1$@–%2$@ %3$@` — the lowest and the highest reading of the period, in the unit they are
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

    // MARK: - Smoking section (iOS-M17 Task 18)

    /// The section's overline, stored upper-case (Turkish folds `i` to `İ`, and a runtime fold
    /// would follow the device locale).
    public static var smokingOverline: String { localized(.smokingOverline) }

    public static var smokingEmptyTitle: String { localized(.smokingEmptyTitle) }
    /// Names the threshold: the figures need entries on at least seven different days.
    public static var smokingEmptyMessage: String { localized(.smokingEmptyMessage) }

    public static var smokingTriggersTitle: String { localized(.smokingTriggersTitle) }
    public static var smokingTriggersSubtitle: String { localized(.smokingTriggersSubtitle) }

    /// `%%%1$lld` / `%1$lld%%` — a whole percent, written the way the language writes one.
    static func smokingPercent(_ percent: Int) -> String {
        String(format: localized(.smokingPercent), percent)
    }

    /// `%1$@, yüzde %2$lld` — one trigger row, spoken as one line.
    static func smokingTriggerDescription(_ trigger: String, _ percent: Int) -> String {
        String(format: localized(.smokingTriggerDescription), trigger, percent)
    }

    public static var smokingTriggersChartDescription: String { localized(.smokingTriggersChartDescription) }

    public static var smokingHeatmapTitle: String { localized(.smokingHeatmapTitle) }
    public static var smokingHeatmapSubtitle: String { localized(.smokingHeatmapSubtitle) }

    /// `%1$@ %2$@: %3$@` — one cell, spoken: the weekday, the hour range, then the count.
    static func smokingHeatmapCell(_ weekday: String, _ range: String, _ count: String) -> String {
        String(format: localized(.smokingHeatmapCell), weekday, range, count)
    }

    /// The two-key plural (spec §9 (h)): `count == 1` reads the English singular. The word is
    /// "kayıt" / "entries", not "kriz" — the cells count every occurrence, slips included
    /// (contract §8.12).
    static func smokingHeatmapCount(_ count: Int) -> String {
        String(format: localized(count == 1 ? .smokingHeatmapCountOne : .smokingHeatmapCount), count)
    }

    /// No possessive suffix on the percentage: the right one depends on how the number is
    /// pronounced, so no single literal fits every value.
    static func smokingHeatmapCaption(_ range: String, _ percent: Int) -> String {
        String(format: localized(.smokingHeatmapCaption), range, percent)
    }

    public static var smokingReductionTitle: String { localized(.smokingReductionTitle) }
    public static var smokingReductionSubtitle: String { localized(.smokingReductionSubtitle) }

    /// `%1$lld. hafta` — the reduction curve's x caption.
    public static func smokingReductionWeek(_ week: Int) -> String {
        String(format: localized(.smokingReductionWeek), week)
    }

    public static func smokingReductionDescription(first: Int, last: Int) -> String {
        String(format: localized(.smokingReductionDescription), first, last)
    }

    public static var smokingAttemptsTitle: String { localized(.smokingAttemptsTitle) }
    public static var smokingAttemptsSubtitle: String { localized(.smokingAttemptsSubtitle) }

    public static func smokingAttemptLabel(_ ordinal: Int) -> String {
        String(format: localized(.smokingAttemptLabel), ordinal)
    }

    /// The two-key plural (spec §9 (h)): `days == 1` reads the English singular.
    public static func smokingAttemptDays(_ days: Int) -> String {
        String(format: localized(days == 1 ? .smokingAttemptDaysOne : .smokingAttemptDays), days)
    }

    public static func smokingAttemptDescription(_ label: String, _ duration: String) -> String {
        String(format: localized(.smokingAttemptDescription), label, duration)
    }

    /// The caption of the vertical line on the overlay chart at the day an attempt began.
    public static var smokingQuitMarker: String { localized(.smokingQuitMarker) }

    /// A trigger's name (`CravingTrigger` -> `trends_smoking_trigger_*`).
    static func smokingTrigger(_ trigger: CravingTrigger) -> String {
        switch trigger {
        case .coffee: localized(.smokingTriggerCoffee)
        case .stress: localized(.smokingTriggerStress)
        case .alcohol: localized(.smokingTriggerAlcohol)
        case .afterMeal: localized(.smokingTriggerAfterMeal)
        case .social: localized(.smokingTriggerSocial)
        case .boredom: localized(.smokingTriggerBoredom)
        case .other: localized(.smokingTriggerOther)
        }
    }

    /// The two-digit hour pair written in the heatmap's row label.
    static func smokingBandShort(_ band: HourBand) -> String {
        switch band {
        case .h08_10: localized(.smokingBandShort0810)
        case .h10_12: localized(.smokingBandShort1012)
        case .h12_14: localized(.smokingBandShort1214)
        case .h14_16: localized(.smokingBandShort1416)
        case .h16_18: localized(.smokingBandShort1618)
        case .h18_22: localized(.smokingBandShort1822)
        case .h22_08: localized(.smokingBandShort2208)
        }
    }

    /// The full clock range, for the caption and for each cell's spoken description.
    static func smokingBandRange(_ band: HourBand) -> String {
        switch band {
        case .h08_10: localized(.smokingBand0810)
        case .h10_12: localized(.smokingBand1012)
        case .h12_14: localized(.smokingBand1214)
        case .h14_16: localized(.smokingBand1416)
        case .h16_18: localized(.smokingBand1618)
        case .h18_22: localized(.smokingBand1822)
        case .h22_08: localized(.smokingBand2208)
        }
    }

    /// ISO weekdays, Monday first: `weekday` is the heatmap's column, 0...6.
    static func smokingWeekdayShort(_ weekday: Int) -> String {
        let keys: [Key] = [
            .smokingWeekdayShort1, .smokingWeekdayShort2, .smokingWeekdayShort3, .smokingWeekdayShort4,
            .smokingWeekdayShort5, .smokingWeekdayShort6, .smokingWeekdayShort7
        ]
        return localized(keys[weekday])
    }

    static func smokingWeekday(_ weekday: Int) -> String {
        let keys: [Key] = [
            .smokingWeekday1, .smokingWeekday2, .smokingWeekday3, .smokingWeekday4,
            .smokingWeekday5, .smokingWeekday6, .smokingWeekday7
        ]
        return localized(keys[weekday])
    }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        case title = "trends_title"
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
        case summaryCount = "trends_summary_count"
        case summaryMinMax = "trends_summary_min_max"
        case summaryDirectionRising = "trends_summary_direction_rising"
        case summaryDirectionFalling = "trends_summary_direction_falling"
        case summaryDirectionStable = "trends_summary_direction_stable"
        case summaryChangeUp = "trends_summary_change_up"
        case summaryChangeDown = "trends_summary_change_down"
        case summaryChangeFlat = "trends_summary_change_flat"
        case summaryChangeNoPrevious = "trends_summary_change_no_previous"
        case summaryChangeNotComputable = "trends_summary_change_not_computable"

        // The M15 overlines, stored upper-case (`TrendsCards.kt:549-560`).
        case metricBloodPressureOverline = "trends_metric_blood_pressure_overline"
        case metricGlucoseOverline = "trends_metric_glucose_overline"
        case metricWeightOverline = "trends_metric_weight_overline"

        // The smoking section (iOS-M17 Task 18), the twin of the `trends_smoking_*` keys.
        case smokingOverline = "trends_smoking_overline"
        case smokingEmptyTitle = "trends_smoking_empty_title"
        case smokingEmptyMessage = "trends_smoking_empty_message"
        case smokingTriggersTitle = "trends_smoking_triggers_title"
        case smokingTriggersSubtitle = "trends_smoking_triggers_subtitle"
        case smokingTriggerCoffee = "trends_smoking_trigger_coffee"
        case smokingTriggerStress = "trends_smoking_trigger_stress"
        case smokingTriggerAlcohol = "trends_smoking_trigger_alcohol"
        case smokingTriggerAfterMeal = "trends_smoking_trigger_after_meal"
        case smokingTriggerSocial = "trends_smoking_trigger_social"
        case smokingTriggerBoredom = "trends_smoking_trigger_boredom"
        case smokingTriggerOther = "trends_smoking_trigger_other"
        case smokingPercent = "trends_smoking_percent"
        case smokingTriggerDescription = "trends_smoking_trigger_description"
        case smokingTriggersChartDescription = "trends_smoking_triggers_chart_description"
        case smokingHeatmapTitle = "trends_smoking_heatmap_title"
        case smokingHeatmapSubtitle = "trends_smoking_heatmap_subtitle"
        case smokingBandShort0810 = "trends_smoking_band_short_08_10"
        case smokingBandShort1012 = "trends_smoking_band_short_10_12"
        case smokingBandShort1214 = "trends_smoking_band_short_12_14"
        case smokingBandShort1416 = "trends_smoking_band_short_14_16"
        case smokingBandShort1618 = "trends_smoking_band_short_16_18"
        case smokingBandShort1822 = "trends_smoking_band_short_18_22"
        case smokingBandShort2208 = "trends_smoking_band_short_22_08"
        case smokingBand0810 = "trends_smoking_band_08_10"
        case smokingBand1012 = "trends_smoking_band_10_12"
        case smokingBand1214 = "trends_smoking_band_12_14"
        case smokingBand1416 = "trends_smoking_band_14_16"
        case smokingBand1618 = "trends_smoking_band_16_18"
        case smokingBand1822 = "trends_smoking_band_18_22"
        case smokingBand2208 = "trends_smoking_band_22_08"
        case smokingWeekdayShort1 = "trends_smoking_weekday_short_1"
        case smokingWeekdayShort2 = "trends_smoking_weekday_short_2"
        case smokingWeekdayShort3 = "trends_smoking_weekday_short_3"
        case smokingWeekdayShort4 = "trends_smoking_weekday_short_4"
        case smokingWeekdayShort5 = "trends_smoking_weekday_short_5"
        case smokingWeekdayShort6 = "trends_smoking_weekday_short_6"
        case smokingWeekdayShort7 = "trends_smoking_weekday_short_7"
        case smokingWeekday1 = "trends_smoking_weekday_1"
        case smokingWeekday2 = "trends_smoking_weekday_2"
        case smokingWeekday3 = "trends_smoking_weekday_3"
        case smokingWeekday4 = "trends_smoking_weekday_4"
        case smokingWeekday5 = "trends_smoking_weekday_5"
        case smokingWeekday6 = "trends_smoking_weekday_6"
        case smokingWeekday7 = "trends_smoking_weekday_7"
        case smokingHeatmapCell = "trends_smoking_heatmap_cell"
        case smokingHeatmapCount = "trends_smoking_heatmap_count"
        case smokingHeatmapCountOne = "trends_smoking_heatmap_count_one"
        case smokingHeatmapCaption = "trends_smoking_heatmap_caption"
        case smokingReductionTitle = "trends_smoking_reduction_title"
        case smokingReductionSubtitle = "trends_smoking_reduction_subtitle"
        case smokingReductionWeek = "trends_smoking_reduction_week"
        case smokingReductionDescription = "trends_smoking_reduction_description"
        case smokingAttemptsTitle = "trends_smoking_attempts_title"
        case smokingAttemptsSubtitle = "trends_smoking_attempts_subtitle"
        case smokingAttemptLabel = "trends_smoking_attempt_label"
        case smokingAttemptDays = "trends_smoking_attempt_days"
        case smokingAttemptDaysOne = "trends_smoking_attempt_days_one"
        case smokingAttemptDescription = "trends_smoking_attempt_description"
        case smokingQuitMarker = "trends_smoking_quit_marker"
    }

    private static func localized(_ key: Key) -> String {
        SalusLocalization.string(key.rawValue, bundle: .module)
    }
}
