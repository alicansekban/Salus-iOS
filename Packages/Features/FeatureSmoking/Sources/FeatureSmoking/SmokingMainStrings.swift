// The accessors for the keys `:feature:smoking` owns on the main screen, the slip and trigger
// sheets and the health stages — an extension of ``SmokingStrings`` so the enum itself stays inside
// SwiftLint's 300-line `type_body_length`. The key names are in `SmokingStrings.Key`, which an
// extension cannot add cases to.
//
// Plurals (`smoking_hero_days`, `smoking_slips`) are two keys selected in code (spec §9 (h)),
// where Android keeps one `<plurals>`: the general key carries the `other` item, `_one` the `one`
// item.

import Foundation

extension SmokingStrings {
    // MARK: - Plain strings

    public static var actionCraving: String { localized(.actionCraving) }
    public static var actionSmoked: String { localized(.actionSmoked) }
    public static var captionCravings: String { localized(.captionCravings) }
    public static var captionNotSmoked: String { localized(.captionNotSmoked) }
    public static var captionRegained: String { localized(.captionRegained) }
    public static var captionSaved: String { localized(.captionSaved) }
    public static var heroOverline: String { localized(.heroOverline) }
    public static var mainHistoryCd: String { localized(.mainHistoryCd) }
    public static var mainSettingsCd: String { localized(.mainSettingsCd) }
    public static var metricCravings: String { localized(.metricCravings) }
    public static var metricNone: String { localized(.metricNone) }
    public static var metricNotSmoked: String { localized(.metricNotSmoked) }
    public static var metricNotSmokedHeated: String { localized(.metricNotSmokedHeated) }
    public static var metricNotSmokedVape: String { localized(.metricNotSmokedVape) }
    public static var metricRegained: String { localized(.metricRegained) }
    public static var metricSaved: String { localized(.metricSaved) }
    public static var slipBody: String { localized(.slipBody) }
    public static var slipConfirm: String { localized(.slipConfirm) }
    public static var slipContinue: String { localized(.slipContinue) }
    public static var slipContinueDesc: String { localized(.slipContinueDesc) }
    public static var slipDismiss: String { localized(.slipDismiss) }
    public static var slipRestart: String { localized(.slipRestart) }
    public static var slipRestartDesc: String { localized(.slipRestartDesc) }
    public static var slipTitle: String { localized(.slipTitle) }
    public static var slipUnitsLabel: String { localized(.slipUnitsLabel) }
    public static var slipUnitsUnit: String { localized(.slipUnitsUnit) }
    public static var stageCardOverline: String { localized(.stageCardOverline) }
    public static var triggerAfterMeal: String { localized(.triggerAfterMeal) }
    public static var triggerAlcohol: String { localized(.triggerAlcohol) }
    public static var triggerBoredom: String { localized(.triggerBoredom) }
    public static var triggerCoffee: String { localized(.triggerCoffee) }
    public static var triggerIntensity: String { localized(.triggerIntensity) }
    public static var triggerIntensityHigh: String { localized(.triggerIntensityHigh) }
    public static var triggerIntensityLow: String { localized(.triggerIntensityLow) }
    public static var triggerOther: String { localized(.triggerOther) }
    public static var triggerSave: String { localized(.triggerSave) }
    public static var triggerSkip: String { localized(.triggerSkip) }
    public static var triggerSocial: String { localized(.triggerSocial) }
    public static var triggerStress: String { localized(.triggerStress) }
    public static var triggerTitle: String { localized(.triggerTitle) }

    // MARK: - Formatted strings

    /// `smoking_hero_days` / `smoking_hero_days_one`: two keys selected in code (spec §9 (h)),
    /// where Android keeps one `<plurals>`.
    public static func heroDays(_ days: Int) -> String {
        String(format: localized(days == 1 ? .heroDaysOne : .heroDays), locale: .current, days)
    }

    /// `smoking_hero_hours_minutes`.
    public static func heroHoursMinutes(_ hours: Int, _ minutes: Int) -> String {
        String(format: localized(.heroHoursMinutes), locale: .current, hours, minutes)
    }

    /// `smoking_hero_hours`.
    public static func heroHours(_ hours: Int) -> String {
        String(format: localized(.heroHours), locale: .current, hours)
    }

    /// `smoking_hero_minutes`.
    public static func heroMinutes(_ minutes: Int) -> String {
        String(format: localized(.heroMinutes), locale: .current, minutes)
    }

    /// `smoking_hero_min_sec`.
    public static func heroMinSec(_ minutes: Int, _ seconds: Int) -> String {
        String(format: localized(.heroMinSec), locale: .current, minutes, seconds)
    }

    /// `smoking_hero_semantics`: the spoken counter, `time` being the whole text on screen.
    public static func heroSemantics(_ time: String) -> String {
        String(format: localized(.heroSemantics), locale: .current, time)
    }

    /// `smoking_since_last`.
    public static func sinceLast(_ time: String) -> String {
        String(format: localized(.sinceLast), locale: .current, time)
    }

    /// `smoking_slips` / `smoking_slips_one`: the same two-key plural as ``heroDays(_:)``.
    public static func slips(_ count: Int) -> String {
        String(format: localized(count == 1 ? .slipsOne : .slips), locale: .current, count)
    }

    /// `smoking_metric_today`.
    public static func metricToday(_ count: Int64) -> String {
        String(format: localized(.metricToday), locale: .current, count)
    }

    /// `smoking_regained_days_hours`.
    public static func regainedDaysHours(_ days: Int64, _ hours: Int) -> String {
        String(format: localized(.regainedDaysHours), locale: .current, days, hours)
    }

    /// `smoking_regained_hours_minutes`.
    public static func regainedHoursMinutes(_ hours: Int, _ minutes: Int) -> String {
        String(format: localized(.regainedHoursMinutes), locale: .current, hours, minutes)
    }

    /// `smoking_regained_minutes`.
    public static func regainedMinutes(_ minutes: Int) -> String {
        String(format: localized(.regainedMinutes), locale: .current, minutes)
    }

    /// `smoking_stage_card_percent`: the ring's centre, "%42" in Turkish and "42%" in English.
    public static func stageCardPercent(_ percent: Int) -> String {
        String(format: localized(.stageCardPercent), locale: .current, percent)
    }

    /// `smoking_stage_remaining_days` / `smoking_stage_remaining_days_one`: the two-key plural,
    /// because the rounded-up rule reads "1 day left" from 23 h on (contract section 8.15).
    public static func stageRemainingDays(_ days: Int) -> String {
        String(format: localized(days == 1 ? .stageRemainingDaysOne : .stageRemainingDays), locale: .current, days)
    }

    /// `smoking_stage_remaining_hours`.
    public static func stageRemainingHours(_ hours: Int) -> String {
        String(format: localized(.stageRemainingHours), locale: .current, hours)
    }

    /// `smoking_stage_remaining_minutes`.
    public static func stageRemainingMinutes(_ minutes: Int) -> String {
        String(format: localized(.stageRemainingMinutes), locale: .current, minutes)
    }
}
