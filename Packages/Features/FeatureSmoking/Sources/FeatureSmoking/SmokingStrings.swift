// The twin of `feature/smoking/src/main/res/values/strings.xml` (Turkish, the source language) and
// `values-en/strings.xml` on branch `feature/m17-smoking-cessation` — every key `:feature:smoking`
// owns so far, name and text verbatim, resolved against this package's own bundle exactly as
// `R.string` resolves against `:feature:smoking`. Later tasks add their keys to this enum and to
// `SmokingStringsTests` in the same commit as the screen that reads them.
//
// **Overlines are stored upper-case** (`smoking_setup_step_of`, the setup field labels): no call
// site ever calls `uppercased()` — Turkish has two dotted i's and the runtime cannot know which one
// a label means.
//
// PLACEHOLDER MAPPING, the one place the port is not byte-for-byte: Java's `%1$s` becomes `%1$@`
// (a Swift `String` under `%s` reads a C pointer) and `%1$d` becomes `%1$lld` (Swift's `Int` is
// 64-bit). `%%` stays `%%` in both. The sentence around the specifier is unchanged, and
// `SmokingStringsTests` pins the rendered text in both languages.
//
// TOOLCHAIN NOTE: a `.xcstrings` is compiled into `.lproj` by Xcode's build system only, so under
// `swift test` a lookup returns the key. The tests therefore assert against the catalog FILE; the
// end-to-end check is the simulator run (see `VitalsStrings.swift` for the full account).

import Foundation
import SalusCommon

/// The strings `:feature:smoking` owns.
public enum SmokingStrings {
    public static var title: String { localized(.title) }
    public static var errorGeneric: String { localized(.errorGeneric) }
    public static var setupTitle: String { localized(.setupTitle) }
    public static var setupContinue: String { localized(.setupContinue) }
    public static var setupStart: String { localized(.setupStart) }
    public static var setupErrorFutureDate: String { localized(.setupErrorFutureDate) }
    public static var setupErrorInvalid: String { localized(.setupErrorInvalid) }
    public static var setupModeTitle: String { localized(.setupModeTitle) }
    public static var setupModeSubtitle: String { localized(.setupModeSubtitle) }
    public static var setupModeQuit: String { localized(.setupModeQuit) }
    public static var setupModeQuitDesc: String { localized(.setupModeQuitDesc) }
    public static var setupModeReduce: String { localized(.setupModeReduce) }
    public static var setupModeReduceDesc: String { localized(.setupModeReduceDesc) }
    public static var setupPrivacy: String { localized(.setupPrivacy) }
    public static var setupProductTitle: String { localized(.setupProductTitle) }
    public static var setupProductSubtitle: String { localized(.setupProductSubtitle) }
    public static var setupProductCigarette: String { localized(.setupProductCigarette) }
    public static var setupProductCigaretteDesc: String { localized(.setupProductCigaretteDesc) }
    public static var setupProductRolled: String { localized(.setupProductRolled) }
    public static var setupProductRolledDesc: String { localized(.setupProductRolledDesc) }
    public static var setupProductHeated: String { localized(.setupProductHeated) }
    public static var setupProductHeatedDesc: String { localized(.setupProductHeatedDesc) }
    public static var setupProductVape: String { localized(.setupProductVape) }
    public static var setupProductVapeDesc: String { localized(.setupProductVapeDesc) }
    public static var setupProductHelper: String { localized(.setupProductHelper) }
    public static var setupAmountTitle: String { localized(.setupAmountTitle) }
    public static var setupAmountSubtitle: String { localized(.setupAmountSubtitle) }
    public static var setupAmountSubtitleVape: String { localized(.setupAmountSubtitleVape) }
    public static var setupUnitsPerDay: String { localized(.setupUnitsPerDay) }
    public static var setupUnitsPerDayUnit: String { localized(.setupUnitsPerDayUnit) }
    public static var setupPackPrice: String { localized(.setupPackPrice) }
    public static var setupPouchPrice: String { localized(.setupPouchPrice) }
    public static var setupUnitsPerPack: String { localized(.setupUnitsPerPack) }
    public static var setupUnitsPerPouch: String { localized(.setupUnitsPerPouch) }
    public static var setupUnitsPerPackUnit: String { localized(.setupUnitsPerPackUnit) }
    public static var setupCurrency: String { localized(.setupCurrency) }
    public static var setupWeeklySpend: String { localized(.setupWeeklySpend) }
    public static var setupVapeSelected: String { localized(.setupVapeSelected) }
    public static var setupChangeProduct: String { localized(.setupChangeProduct) }
    public static var setupQuickAddLabel: String { localized(.setupQuickAddLabel) }
    public static var setupSummaryQuit: String { localized(.setupSummaryQuit) }
    public static var setupSummaryReduce: String { localized(.setupSummaryReduce) }
    public static var setupQuitTitle: String { localized(.setupQuitTitle) }
    public static var setupQuitSubtitle: String { localized(.setupQuitSubtitle) }
    public static var setupQuitWhen: String { localized(.setupQuitWhen) }
    public static var setupQuitNow: String { localized(.setupQuitNow) }
    public static var setupQuitEdit: String { localized(.setupQuitEdit) }
    public static var setupReasonLabel: String { localized(.setupReasonLabel) }
    public static var setupReasonPlaceholder: String { localized(.setupReasonPlaceholder) }
    public static var setupReasonHint: String { localized(.setupReasonHint) }
    public static var setupReduceTitle: String { localized(.setupReduceTitle) }
    public static var setupReduceSubtitle: String { localized(.setupReduceSubtitle) }
    public static var setupDailyLimit: String { localized(.setupDailyLimit) }
    public static var setupDailyLimitUnit: String { localized(.setupDailyLimitUnit) }
    public static var quitSheetTitle: String { localized(.quitSheetTitle) }
    public static var quitSheetTime: String { localized(.quitSheetTime) }
    public static var quitSheetFuture: String { localized(.quitSheetFuture) }
    public static var quitSheetTimeDialog: String { localized(.quitSheetTimeDialog) }

    // MARK: - Formatted strings

    /// `smoking_setup_step_of`.
    public static func setupStepOf(_ step: Int, _ count: Int) -> String {
        String(format: localized(.setupStepOf), locale: .current, step, count)
    }

    /// `smoking_setup_quick_add`.
    public static func setupQuickAdd(_ symbol: String, _ amount: Int) -> String {
        String(format: localized(.setupQuickAdd), locale: .current, symbol, amount)
    }

    /// `smoking_setup_summary_daily`.
    public static func setupSummaryDaily(_ perDay: String, _ perYear: String) -> String {
        String(format: localized(.setupSummaryDaily), locale: .current, perDay, perYear)
    }

    /// `smoking_setup_summary_weekly`.
    public static func setupSummaryWeekly(_ perWeek: String, _ perYear: String) -> String {
        String(format: localized(.setupSummaryWeekly), locale: .current, perWeek, perYear)
    }

    /// `smoking_setup_quit_today`.
    public static func setupQuitToday(_ time: String) -> String {
        String(format: localized(.setupQuitToday), locale: .current, time)
    }

    /// `smoking_setup_limit_suggestion`.
    public static func setupLimitSuggestion(_ current: Int) -> String {
        String(format: localized(.setupLimitSuggestion), locale: .current, current)
    }

    // MARK: - Milestone notifications (iOS-M17 Task 17)

    /// `smoking_notification_stage` — "Yeni aşama: %1$s" around a stage title.
    public static func notificationStage(_ stageTitle: String) -> String {
        String(format: localized(.notificationStage), locale: .current, stageTitle)
    }

    /// The two-key plural (spec 9 (h)): `days == 1` reads the English singular.
    public static func notificationDays(_ days: Int) -> String {
        String(format: localized(days == 1 ? .notificationDaysOne : .notificationDays), locale: .current, days)
    }

    /// The two-key plural for a whole number of years.
    public static func notificationYears(_ years: Int) -> String {
        String(format: localized(years == 1 ? .notificationYearsOne : .notificationYears), locale: .current, years)
    }

    /// `smoking_notification_units` — "%1$s adet içmedin".
    public static func notificationUnits(_ units: String) -> String {
        String(format: localized(.notificationUnits), locale: .current, units)
    }

    /// `smoking_notification_money` — "%1$s biriktirdin".
    public static func notificationMoney(_ amount: String) -> String {
        String(format: localized(.notificationMoney), locale: .current, amount)
    }

    public static var notificationStageHint: String { localized(.notificationStageHint) }
    public static var notificationCheer: String { localized(.notificationCheer) }
    public static var notificationEveningTitle: String { localized(.notificationEveningTitle) }
    public static var notificationEveningText: String { localized(.notificationEveningText) }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        case title = "smoking_title"
        case errorGeneric = "smoking_error_generic"
        case setupTitle = "smoking_setup_title"
        case setupStepOf = "smoking_setup_step_of"
        case setupContinue = "smoking_setup_continue"
        case setupStart = "smoking_setup_start"
        case setupErrorFutureDate = "smoking_setup_error_future_date"
        case setupErrorInvalid = "smoking_setup_error_invalid"
        case setupModeTitle = "smoking_setup_mode_title"
        case setupModeSubtitle = "smoking_setup_mode_subtitle"
        case setupModeQuit = "smoking_setup_mode_quit"
        case setupModeQuitDesc = "smoking_setup_mode_quit_desc"
        case setupModeReduce = "smoking_setup_mode_reduce"
        case setupModeReduceDesc = "smoking_setup_mode_reduce_desc"
        case setupPrivacy = "smoking_setup_privacy"
        case setupProductTitle = "smoking_setup_product_title"
        case setupProductSubtitle = "smoking_setup_product_subtitle"
        case setupProductCigarette = "smoking_setup_product_cigarette"
        case setupProductCigaretteDesc = "smoking_setup_product_cigarette_desc"
        case setupProductRolled = "smoking_setup_product_rolled"
        case setupProductRolledDesc = "smoking_setup_product_rolled_desc"
        case setupProductHeated = "smoking_setup_product_heated"
        case setupProductHeatedDesc = "smoking_setup_product_heated_desc"
        case setupProductVape = "smoking_setup_product_vape"
        case setupProductVapeDesc = "smoking_setup_product_vape_desc"
        case setupProductHelper = "smoking_setup_product_helper"
        case setupAmountTitle = "smoking_setup_amount_title"
        case setupAmountSubtitle = "smoking_setup_amount_subtitle"
        case setupAmountSubtitleVape = "smoking_setup_amount_subtitle_vape"
        case setupUnitsPerDay = "smoking_setup_units_per_day"
        case setupUnitsPerDayUnit = "smoking_setup_units_per_day_unit"
        case setupPackPrice = "smoking_setup_pack_price"
        case setupPouchPrice = "smoking_setup_pouch_price"
        case setupUnitsPerPack = "smoking_setup_units_per_pack"
        case setupUnitsPerPouch = "smoking_setup_units_per_pouch"
        case setupUnitsPerPackUnit = "smoking_setup_units_per_pack_unit"
        case setupCurrency = "smoking_setup_currency"
        case setupWeeklySpend = "smoking_setup_weekly_spend"
        case setupVapeSelected = "smoking_setup_vape_selected"
        case setupChangeProduct = "smoking_setup_change_product"
        case setupQuickAddLabel = "smoking_setup_quick_add_label"
        case setupQuickAdd = "smoking_setup_quick_add"
        case setupSummaryDaily = "smoking_setup_summary_daily"
        case setupSummaryWeekly = "smoking_setup_summary_weekly"
        case setupSummaryQuit = "smoking_setup_summary_quit"
        case setupSummaryReduce = "smoking_setup_summary_reduce"
        case setupQuitTitle = "smoking_setup_quit_title"
        case setupQuitSubtitle = "smoking_setup_quit_subtitle"
        case setupQuitWhen = "smoking_setup_quit_when"
        case setupQuitNow = "smoking_setup_quit_now"
        case setupQuitToday = "smoking_setup_quit_today"
        case setupQuitEdit = "smoking_setup_quit_edit"
        case setupReasonLabel = "smoking_setup_reason_label"
        case setupReasonPlaceholder = "smoking_setup_reason_placeholder"
        case setupReasonHint = "smoking_setup_reason_hint"
        case setupReduceTitle = "smoking_setup_reduce_title"
        case setupReduceSubtitle = "smoking_setup_reduce_subtitle"
        case setupDailyLimit = "smoking_setup_daily_limit"
        case setupDailyLimitUnit = "smoking_setup_daily_limit_unit"
        case setupLimitSuggestion = "smoking_setup_limit_suggestion"
        case quitSheetTitle = "smoking_quit_sheet_title"
        case quitSheetTime = "smoking_quit_sheet_time"
        case quitSheetFuture = "smoking_quit_sheet_future"
        case quitSheetTimeDialog = "smoking_quit_sheet_time_dialog"
        case actionCraving = "smoking_action_craving"
        case actionSmoked = "smoking_action_smoked"
        case captionCravings = "smoking_caption_cravings"
        case captionNotSmoked = "smoking_caption_not_smoked"
        case captionRegained = "smoking_caption_regained"
        case captionSaved = "smoking_caption_saved"
        case heroDays = "smoking_hero_days"
        case heroDaysOne = "smoking_hero_days_one"
        case heroHours = "smoking_hero_hours"
        case heroHoursMinutes = "smoking_hero_hours_minutes"
        case heroMinSec = "smoking_hero_min_sec"
        case heroMinutes = "smoking_hero_minutes"
        case heroOverline = "smoking_hero_overline"
        case heroSemantics = "smoking_hero_semantics"
        case mainHistoryCd = "smoking_main_history_cd"
        case mainSettingsCd = "smoking_main_settings_cd"
        case metricCravings = "smoking_metric_cravings"
        case metricNone = "smoking_metric_none"
        case metricNotSmoked = "smoking_metric_not_smoked"
        case metricNotSmokedHeated = "smoking_metric_not_smoked_heated"
        case metricNotSmokedVape = "smoking_metric_not_smoked_vape"
        case metricRegained = "smoking_metric_regained"
        case metricSaved = "smoking_metric_saved"
        case metricToday = "smoking_metric_today"
        case regainedDaysHours = "smoking_regained_days_hours"
        case regainedHoursMinutes = "smoking_regained_hours_minutes"
        case regainedMinutes = "smoking_regained_minutes"
        case sinceLast = "smoking_since_last"
        case slipBody = "smoking_slip_body"
        case slipConfirm = "smoking_slip_confirm"
        case slipContinue = "smoking_slip_continue"
        case slipContinueDesc = "smoking_slip_continue_desc"
        case slipDismiss = "smoking_slip_dismiss"
        case slipRestart = "smoking_slip_restart"
        case slipRestartDesc = "smoking_slip_restart_desc"
        case slipTitle = "smoking_slip_title"
        case slipUnitsLabel = "smoking_slip_units_label"
        case slipUnitsUnit = "smoking_slip_units_unit"
        case slips = "smoking_slips"
        case slipsOne = "smoking_slips_one"
        case stageCardOverline = "smoking_stage_card_overline"
        case stageCardPercent = "smoking_stage_card_percent"
        case stageH10yStatement = "smoking_stage_h_10y_statement"
        case stageH10yTitle = "smoking_stage_h_10y_title"
        case stageH12hStatement = "smoking_stage_h_12h_statement"
        case stageH12hTitle = "smoking_stage_h_12h_title"
        case stageH15yStatement = "smoking_stage_h_15y_statement"
        case stageH15yTitle = "smoking_stage_h_15y_title"
        case stageH1moStatement = "smoking_stage_h_1mo_statement"
        case stageH1moTitle = "smoking_stage_h_1mo_title"
        case stageH1yStatement = "smoking_stage_h_1y_statement"
        case stageH1yTitle = "smoking_stage_h_1y_title"
        case stageH20mStatement = "smoking_stage_h_20m_statement"
        case stageH20mTitle = "smoking_stage_h_20m_title"
        case stageH2wStatement = "smoking_stage_h_2w_statement"
        case stageH2wTitle = "smoking_stage_h_2w_title"
        case stageH48hStatement = "smoking_stage_h_48h_statement"
        case stageH48hTitle = "smoking_stage_h_48h_title"
        case stageH5yStatement = "smoking_stage_h_5y_statement"
        case stageH5yTitle = "smoking_stage_h_5y_title"
        case stageH72hStatement = "smoking_stage_h_72h_statement"
        case stageH72hTitle = "smoking_stage_h_72h_title"
        case stageRemainingDays = "smoking_stage_remaining_days"
        case stageRemainingHours = "smoking_stage_remaining_hours"
        case stageRemainingMinutes = "smoking_stage_remaining_minutes"
        case triggerAfterMeal = "smoking_trigger_after_meal"
        case triggerAlcohol = "smoking_trigger_alcohol"
        case triggerBoredom = "smoking_trigger_boredom"
        case triggerCoffee = "smoking_trigger_coffee"
        case triggerIntensity = "smoking_trigger_intensity"
        case triggerIntensityHigh = "smoking_trigger_intensity_high"
        case triggerIntensityLow = "smoking_trigger_intensity_low"
        case triggerOther = "smoking_trigger_other"
        case triggerSave = "smoking_trigger_save"
        case triggerSkip = "smoking_trigger_skip"
        case triggerSocial = "smoking_trigger_social"
        case triggerStress = "smoking_trigger_stress"
        case triggerTitle = "smoking_trigger_title"
        case notificationStage = "smoking_notification_stage"
        case notificationDays = "smoking_notification_days"
        case notificationDaysOne = "smoking_notification_days_one"
        case notificationYears = "smoking_notification_years"
        case notificationYearsOne = "smoking_notification_years_one"
        case notificationUnits = "smoking_notification_units"
        case notificationMoney = "smoking_notification_money"
        case notificationStageHint = "smoking_notification_stage_hint"
        case notificationCheer = "smoking_notification_cheer"
        case notificationEveningTitle = "smoking_notification_evening_title"
        case notificationEveningText = "smoking_notification_evening_text"
    }

    static func localized(_ key: Key) -> String {
        SalusLocalization.string(key.rawValue, bundle: .module)
    }
}
