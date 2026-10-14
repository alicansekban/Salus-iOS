// The accessors for the keys `:feature:smoking` owns on the settings screen and its sheets and
// confirmations — an extension of ``SmokingStrings`` so the enum itself stays inside SwiftLint's
// 300-line `type_body_length`. The key names are in `SmokingStrings.Key`.

import Foundation
import SalusCommon

extension SmokingStrings {
    public static var settingsConfirmChange: String { localized(.settingsConfirmChange) }
    public static var settingsCurrency: String { localized(.settingsCurrency) }
    public static var settingsCurrencyConfirmMessage: String { localized(.settingsCurrencyConfirmMessage) }
    public static var settingsCurrencyConfirmTitle: String { localized(.settingsCurrencyConfirmTitle) }
    public static var settingsCurrencySheetTitle: String { localized(.settingsCurrencySheetTitle) }
    public static var settingsErrorOverlap: String { localized(.settingsErrorOverlap) }
    public static var settingsEvening: String { localized(.settingsEvening) }
    public static var settingsEveningDesc: String { localized(.settingsEveningDesc) }
    public static var settingsLimit: String { localized(.settingsLimit) }
    public static var settingsLimitSheetTitle: String { localized(.settingsLimitSheetTitle) }
    public static var settingsNotifications: String { localized(.settingsNotifications) }
    public static var settingsNotificationsDesc: String { localized(.settingsNotificationsDesc) }
    public static var settingsPrice: String { localized(.settingsPrice) }
    public static var settingsPriceNote: String { localized(.settingsPriceNote) }
    public static var settingsPriceSheetTitle: String { localized(.settingsPriceSheetTitle) }
    public static var settingsQuitDate: String { localized(.settingsQuitDate) }
    public static var settingsQuitDateConfirmMessage: String { localized(.settingsQuitDateConfirmMessage) }
    public static var settingsQuitDateConfirmTitle: String { localized(.settingsQuitDateConfirmTitle) }
    public static var settingsReason: String { localized(.settingsReason) }
    public static var settingsReasonEmpty: String { localized(.settingsReasonEmpty) }
    public static var settingsReasonHint: String { localized(.settingsReasonHint) }
    public static var settingsReasonLabel: String { localized(.settingsReasonLabel) }
    public static var settingsReasonSheetTitle: String { localized(.settingsReasonSheetTitle) }
    public static var settingsReduceSheetConfirm: String { localized(.settingsReduceSheetConfirm) }
    public static var settingsReduceSheetTitle: String { localized(.settingsReduceSheetTitle) }
    public static var settingsReset: String { localized(.settingsReset) }
    public static var settingsResetConfirm: String { localized(.settingsResetConfirm) }
    public static var settingsResetConfirmMessage: String { localized(.settingsResetConfirmMessage) }
    public static var settingsResetConfirmTitle: String { localized(.settingsResetConfirmTitle) }
    public static var settingsResetDesc: String { localized(.settingsResetDesc) }
    public static var settingsSave: String { localized(.settingsSave) }
    public static var settingsSectionData: String { localized(.settingsSectionData) }
    public static var settingsSectionHabit: String { localized(.settingsSectionHabit) }
    public static var settingsSectionMode: String { localized(.settingsSectionMode) }
    public static var settingsSectionNotifications: String { localized(.settingsSectionNotifications) }
    public static var settingsSwitchToQuit: String { localized(.settingsSwitchToQuit) }
    public static var settingsSwitchToQuitDesc: String { localized(.settingsSwitchToQuitDesc) }
    public static var settingsSwitchToReduce: String { localized(.settingsSwitchToReduce) }
    public static var settingsSwitchToReduceDesc: String { localized(.settingsSwitchToReduceDesc) }
    public static var settingsTitle: String { localized(.settingsTitle) }

    // MARK: - Formatted strings

    /// `smoking_settings_price_value`: "₺4,75 / adet".
    public static func settingsPriceValue(_ money: String) -> String {
        String(format: localized(.settingsPriceValue), locale: .current, money)
    }

    /// `smoking_settings_price_value_vape`: "₺1,43 / gün".
    public static func settingsPriceValueVape(_ money: String) -> String {
        String(format: localized(.settingsPriceValueVape), locale: .current, money)
    }

    /// `smoking_settings_limit_value`: "10 adet".
    public static func settingsLimitValue(_ limit: Int) -> String {
        String(format: localized(.settingsLimitValue), locale: .current, limit)
    }

    /// `smoking_settings_reason_value`: the reason in typographic quotes.
    public static func settingsReasonValue(_ reason: String) -> String {
        String(format: localized(.settingsReasonValue), locale: .current, reason)
    }

    // MARK: - Keys

    /// The catalog keys of the settings screen and its sheets, named once. They sit beside their accessors, and not in
    /// ``SmokingStrings/Key``, so that enum stays inside SwiftLint's 300-line `type_body_length`;
    /// the parity test checks the union of the enums against the catalog.
    enum SettingsKey: String, CaseIterable {
        case settingsConfirmChange = "smoking_settings_confirm_change"
        case settingsCurrency = "smoking_settings_currency"
        case settingsCurrencyConfirmMessage = "smoking_settings_currency_confirm_message"
        case settingsCurrencyConfirmTitle = "smoking_settings_currency_confirm_title"
        case settingsCurrencySheetTitle = "smoking_settings_currency_sheet_title"
        case settingsErrorOverlap = "smoking_settings_error_overlap"
        case settingsEvening = "smoking_settings_evening"
        case settingsEveningDesc = "smoking_settings_evening_desc"
        case settingsLimit = "smoking_settings_limit"
        case settingsLimitSheetTitle = "smoking_settings_limit_sheet_title"
        case settingsLimitValue = "smoking_settings_limit_value"
        case settingsNotifications = "smoking_settings_notifications"
        case settingsNotificationsDesc = "smoking_settings_notifications_desc"
        case settingsPrice = "smoking_settings_price"
        case settingsPriceNote = "smoking_settings_price_note"
        case settingsPriceSheetTitle = "smoking_settings_price_sheet_title"
        case settingsPriceValue = "smoking_settings_price_value"
        case settingsPriceValueVape = "smoking_settings_price_value_vape"
        case settingsQuitDate = "smoking_settings_quit_date"
        case settingsQuitDateConfirmMessage = "smoking_settings_quit_date_confirm_message"
        case settingsQuitDateConfirmTitle = "smoking_settings_quit_date_confirm_title"
        case settingsReason = "smoking_settings_reason"
        case settingsReasonEmpty = "smoking_settings_reason_empty"
        case settingsReasonHint = "smoking_settings_reason_hint"
        case settingsReasonLabel = "smoking_settings_reason_label"
        case settingsReasonSheetTitle = "smoking_settings_reason_sheet_title"
        case settingsReasonValue = "smoking_settings_reason_value"
        case settingsReduceSheetConfirm = "smoking_settings_reduce_sheet_confirm"
        case settingsReduceSheetTitle = "smoking_settings_reduce_sheet_title"
        case settingsReset = "smoking_settings_reset"
        case settingsResetConfirm = "smoking_settings_reset_confirm"
        case settingsResetConfirmMessage = "smoking_settings_reset_confirm_message"
        case settingsResetConfirmTitle = "smoking_settings_reset_confirm_title"
        case settingsResetDesc = "smoking_settings_reset_desc"
        case settingsSave = "smoking_settings_save"
        case settingsSectionData = "smoking_settings_section_data"
        case settingsSectionHabit = "smoking_settings_section_habit"
        case settingsSectionMode = "smoking_settings_section_mode"
        case settingsSectionNotifications = "smoking_settings_section_notifications"
        case settingsSwitchToQuit = "smoking_settings_switch_to_quit"
        case settingsSwitchToQuitDesc = "smoking_settings_switch_to_quit_desc"
        case settingsSwitchToReduce = "smoking_settings_switch_to_reduce"
        case settingsSwitchToReduceDesc = "smoking_settings_switch_to_reduce_desc"
        case settingsTitle = "smoking_settings_title"
    }

    static func localized(_ key: SettingsKey) -> String {
        SalusLocalization.string(key.rawValue, bundle: .module)
    }
}
